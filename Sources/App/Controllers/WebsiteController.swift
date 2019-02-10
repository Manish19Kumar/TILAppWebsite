import Vapor
import Leaf
import Fluent
import Authentication

// 1. Declare a new WebsiteController type that conforms to RouteCollection.
struct WebsiteController: RouteCollection {
    
    func boot(router: Router) throws {
        let authSessionRoutes = router.grouped(User.authSessionsMiddleware())
        
        authSessionRoutes.get(use: indexHandler)
        authSessionRoutes.get("acronyms", Acronym.parameter, use: acronymHandler)
        authSessionRoutes.get("users", use: allUsersHandler)
        authSessionRoutes.get("users", User.parameter, use: userHandler)
        
        authSessionRoutes.get("categories", use: allCategoriesHandler)
        authSessionRoutes.get("categories", Category.parameter, use: categoryHandler)
        
        authSessionRoutes.get("login", use: loginHandler)
        authSessionRoutes.post(LoginPostData.self, at: "login", use: loginPostHandler)
        
        authSessionRoutes.post("logout", use: logoutHandler)
        // This creates a new route group, extending from authSessionRoutes, that includes RedirectMiddleware. The application runs a request through RedirectMiddleware before it reaches the route handler, but after AuthenticationSessionsMiddleware. This allows RedirectMiddleware to check for an authenticated user. RedirectMiddleware requires you to specify the path for redirecting unauthenticated users and the Authenticatable type to check for. In this case, that’s your User model.
        let protectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<User>(path: "/login"))
        protectedRoutes.get("acronyms", "create", use: createAcronymHandler)
        protectedRoutes.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler)
        protectedRoutes.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)
        
    }
    
    // Old boot function withou proper authentication
    // 2. Implement boot(router:) as required by RouteCollection.
    /*func boot(router: Router) throws {
        // 3. Register indexHandler(_:) to process GET requests to the router’s root path, i.e., a request to /.
        router.get(use: indexHandler)
        
        router.get("acronyms", Acronym.parameter, use: acronymHandler)
        router.get("users", User.parameter, use: userHandler)
        router.get("users", use: allUsersHandler)
        
        // 1. Register a route at /categories that accepts GET requests and calls allCategoriesHandler(_:).
        router.get("categories", use: allCategoriesHandler)
        // 2. Register a route at /categories/<CATEGORY ID> that accepts GET requests and calls categoryHandler(_:).
        router.get("categories", Category.parameter, use: categoryHandler)
        
        // 1. Register a route at /acronyms/create that accepts GET requests and calls createAcronymHandler(_:).
        router.get("acronyms", "create", use: createAcronymHandler)
        // 2. Register a route at /acronyms/create that accepts POST requests and calls createAcronymPostHandler(_:acronym:). This also decodes the request’s body to an Acronym.
        router.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler)
        
        router.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
        router.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)
        router.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)
        
        // 1. Route GET requests for /login to loginHandler(_:).
        router.get("login", use: loginHandler)
        // 2. Route POST requests for /login to loginPostHandler(_:userData:), decoding the request body into LoginPostData.
        router.post(LoginPostData.self, at: "login", use: loginPostHandler)
        
    }*/
    
    // 4. Implement indexHandler(_:) that returns Future<View>.
    /*
     func indexHandler(_ req: Request) throws -> Future<View> {
        // 5. Render the index template and return the result.
        
        // 1 Create an IndexContext containing the desired title.
        let context = IndexContext(title: "Homepage")
        // 2 Pass the context to Leaf as the second parameter to render(_:_:).
        return try req.view().render("index",context)
    }
 */
    
    func indexHandler(_ req: Request) throws -> Future<View> {
        // 1. Use a Fluent query to get all the acronyms from the database.
        return Acronym.query(on: req)
        .all()
            .flatMap(to: View.self, { (acronyms) in
                // 2. Add the acronyms to IndexContext if there are any, otherwise set the variable to nil. This is easier for Leaf to manage than an empty array.
                let acronymsData = acronyms.isEmpty ? nil : acronyms
                
                // 1. Check if the request contains an authenticated user.
                let userLoggedIn = try req.isAuthenticated(User.self)
                
                // 1.1. See if a cookie called cookies-accepted exists. If it doesn’t, set the showCookieMessage flag to true. You can read cookies from the request and set them on a response.
                let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
                // 2. Pass the result to the new flag in IndexContext.
                let context = IndexContext(title: "Homepage", acronyms: acronymsData, userLoggedIn: userLoggedIn, showCookieMessage: showCookieMessage)
                return try req.view().render("index", context)
            })
    }
    
    // 1. Declare a new route handler, acronymHandler(_:), that returns Future<View>.
    func acronymHandler(_ req: Request) throws -> Future<View> {
        // 2. Extract the acronym from the request’s parameters and unwrap the result.
        return try req.parameters.next(Acronym.self)
            .flatMap(to: View.self, { (acronym) in
                // 3. Get the user for acronym and unwrap the result.
                return acronym.user
                    .get(on: req)
                    .flatMap(to: View.self, { (user) in
                        // 4. Create an AcronymContext that contains the appropriate details and render the page using the acronym.leaf template.
//                        let context = AcronymContext(title: acronym.short,
 //                                                    acronym: acronym,
//                                                     user: user)
                        let categories = try acronym.categories.query(on: req).all()
                        let context = AcronymContext(
                            title: acronym.short,
                            acronym: acronym,
                            user:  user,
                            categories: categories)
                        return try req.view().render("acronym", context)
                    })
            })
    }
    
    // 1. Define the route handler for the user page that returns Future<View>.
    func userHandler(_ req: Request) throws -> Future<View> {
        // 2. Get the user from the request’s parameters and unwrap the future.
        return try req.parameters.next(User.self)
            .flatMap(to: View.self, { (user) in
                // 3. Get the user’s acronyms using the computed property and unwrap the future.
                return try user.acronyms
                    .query(on: req)
                    .all()
                    .flatMap(to: View.self, { (acronyms) in
                        // 4. Create a UserContext, then render the user.leaf template, returning the result. In this case, you’re not setting the acronyms array to nil if it’s empty. This is not required as you’re checking the count in template.
                        let context = UserContext(
                            title: user.name,
                            user: user,
                            acronyms: acronyms)
                        return try req.view().render("user", context)
                    })
            })
    }
    
    // 1. Define a route handler for the “All Users” page that returns Future<View>.
    func allUsersHandler(_ req: Request) throws -> Future<View> {
        // 2. Get the users from the database and unwrap the future.
        return User.query(on: req)
            .all()
            .flatMap(to: View.self, { (users) in
                // 3. Create an AllUsersContext and render the allUsers.leaf template, then return the result.
                let context = AllUsersContext(
                    title: "All Users",
                    users: users)
                return try req.view().render("allUsers", context)
            })
    }
    
    func allCategoriesHandler(_ req: Request) throws -> Future<View> {
        // 1. Create an AllCategoriesContext. Notice that the context includes the query result directly, since Leaf can handle futures.
        let categories = Category.query(on: req).all()
        let context = AllCategoriesContext(categories: categories)
        // 2. Render the allCategories.leaf template with the provided context.
        return try req.view().render("allCategories", context)
    }
    
    func categoryHandler(_ req: Request) throws -> Future<View> {
        // 1. Get the category from the request’s parameters and unwrap the returned future.
        return try req.parameters.next(Category.self)
            .flatMap(to: View.self, { (category) in
                // 2. Create a query to get all the acronyms for the category. This is a Future<[Acronym]>.
                let acronyms = try category.acronyms.query(on: req).all()
                // 3. Create a context for the page.
                let context = CategoryContext(
                    title: category.name,
                    category: category,
                    acronyms: acronyms)
                // 4. Return a rendered view using the category.leaf template.
                return try req.view().render("category", context)
            })
    }
    
    func createAcronymHandler(_ req: Request) throws -> Future<View> {
        // 1. Create a context by passing in a query to get all of the users.
//        let context = CreateAcronymContext(
//            users: User.query(on: req).all()) No longer required
        // 1.1. Create a token using 16 bytes of randomly generated data, base64 encoded.
        let token = try CryptoRandom()
            .generateData(count: 16)
            .base64EncodedString()
        // 1.2. Initialize CreateAcronymContext with the created token.
        let context = CreateAcronymContext(csrfToken: token)
        // 1.3. Save the token into the request’s session under the CSRF_TOKEN key.
        try req.session()["CSRF_TOKEN"] = token
        // 2. Render the page using the createAcronym.leaf template.
        return try req.view().render("createAcronym", context)
    }
    
    // 1. Declare a route handler that takes Acronym as a parameter. Vapor automatically decodes the form data to an Acronym object.
    /*
     // This function doesnot integrate acronym with category
     func createAcronymPostHandler(
        _ req: Request, acronym: Acronym) throws -> Future<Response> {
        // 2. Save the provided acronym and unwrap the returned future.
        return acronym.save(on: req).map(to: Response.self, { (acronym) in
            // 3. Ensure that the ID has been set, otherwise throw a 500 Internal Server Error.
            guard let id = acronym.id else {
                throw Abort(.internalServerError)
            }
            // 4. Redirect to the page for the newly created acronym.
            return req.redirect(to: "/acronyms/\(id)")
        })
    }
 */
    // 1. Change the Content type of route handler to accept CreateAcronymData.
    func createAcronymPostHandler(
        _ req: Request, data: CreateAcronymData) throws -> Future<Response> {
        
        // 1.1. Get the expected token from the request’s session. This is the token you saved in createAcronymHandler(_:).
        let expectedToken = try req.session()["CSRF_TOKEN"]
        
        // 1.2. Clear the CSRF token now that you’ve used it. You generate a new token with each form.
        try req.session()["CSRF_TOKEN"] = nil
        
        // 1.3. Ensure the provided token matches the expected token; otherwise, throw a 400 Bad Request error.
        guard expectedToken == data.csrfToken else {
            throw Abort(.badRequest)
        }
        let user = try req.requireAuthenticated(User.self) // Get authenticated user for current session
        // 2. Create an Acronym object to save as it’s no longer passed into the route.
        let acronym = try Acronym(
            short: data.short,
            long: data.long,
            userID: user.requireID())
        // 3. Call flatMap(to:) instead of map(to:) as you now return a Future<Response> in the closure.
        return acronym.save(on: req)
            .flatMap(to: Response.self, { (acronym) in
                guard let id = acronym.id else {
                    throw Abort(.internalServerError)
                }
                
                // 4. Define an array of futures to store the save operations.
                var categorySaves: [Future<Void>] = []
                // 5. Loop through all the categories provided to the request and add the results of Category.addCategory(_:to:on:) to the array.
                for category in data.categories ?? [] {
                    try categorySaves.append(
                        Category.addCategory(category, to: acronym, on: req))
                }
                // 6. Flatten the array to complete all the Fluent operations and transform the result to a Response. Redirect the page to the new acronym’s page.
                let redirect = req.redirect(to: "/acronyms/\(id)")
                return categorySaves.flatten(on: req)
                    .transform(to: redirect)
            })
    }
    
    func editAcronymHandler(_ req: Request) throws -> Future<View> {
        // 1. Get the acronym to edit from the request’s parameter and unwrap the future.
        return try req.parameters.next(Acronym.self)
            .flatMap(to: View.self, { (acronym) in
                // 2. Create a context to edit the acronym, passing in all the users.
//                let users = User.query(on: req).all() No longer required
                let categories = try acronym.categories.query(on: req).all()
                let context = EditAcronymContext(
                    acronym: acronym,
//                    users: users, No longer required
                    categories: categories)
                // 3. Render the page using the createAcronym.leaf template, the same template used for the create page.
                return try req.view().render("createAcronym", context)
            })
    }
    
    /*func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
        // 1. Use the convenience form of flatMap to get the acronym from the request’s parameter, decode the incoming data and unwrap both results.
        return try flatMap(
            to: Response.self,
            req.parameters.next(Acronym.self),
            req.content.decode(Acronym.self)
        ) {
            // 2. Update the acronym with the new data.
            acronym, data in
            acronym.short = data.short
            acronym.long = data.long
            acronym.userID = data.userID
            
            // 3. Save the result and unwrap the returned future.
            return acronym.save(on: req)
                .map(to: Response.self, { (savedAcronym) in
                    // 4. Ensure the ID has been set, otherwise throw a 500 Internal Server error.
                    guard let id = savedAcronym.id else {
                        throw Abort(.internalServerError)
                    }
                    // 5. Return a redirect to the updated acronym’s page.
                    return req.redirect(to: "/acronyms/\(id)")
                })
        }
    }
 */
    func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
        // 1. Change the content type the request decodes to CreateAcronymData.
        return try flatMap(to: Response.self,
                           req.parameters.next(Acronym.self),
                           req.content.decode(CreateAcronymData.self),
                           { (acronym, data) in
                            
                            let user = try req.requireAuthenticated(User.self)
                            acronym.short = data.short
                            acronym.long = data.long
                            acronym.userID = try user.requireID()
                            
                            // 2. Use flatMap(to:) on save(on:) since the closure now returns a future.
                            return acronym.save(on: req)
                                .flatMap(to: Response.self, { (savedAcronym) in
                                    guard let id = savedAcronym.id else {
                                        throw Abort(.internalServerError)
                                    }
                            // 3. Get all categories from the database.
                            return try acronym.categories.query(on: req).all()
                                .flatMap(to: Response.self, { (existingCategories) in
                                    // 4. Create an array of category names from the categories in the database.
                                    let existingStringArray = existingCategories.map{ $0.name }
                                    
                                    // 5. Create a Set for the categories in the database and another for the categories supplied with the request.
                                    let existingSet = Set<String>(existingStringArray)
                                    let newSet = Set<String>(data.categories ?? [])
                                    
                                    // 6. Calculate the categories to add to the acronym and the categories to remove.
                                    let categoriesToAdd = newSet.subtracting(existingSet)
                                    let categoriesToRemove = existingSet.subtracting(newSet)
                                    
                                    // 7. Create an array of category operation results.
                                    var categoryResults: [Future<Void>] = []
                                    
                                    // 8. Loop through all the categories to add and call Category.addCategory(_:to:on:) to set up the relationship. Add each result to the results array.
                                    for newCategory in categoriesToAdd {
                                        categoryResults.append(try Category.addCategory(
                                            newCategory,
                                            to: acronym,
                                            on: req))
                                    }
                                    
                                    // 9. Loop through all the categories to remove from the acronym.
                                    for categoryNameToRemove in categoriesToRemove {
                                        // 10. Get the Category object from the name of the category to remove.
                                        let categoryToRemove = existingCategories.first {
                                            $0.name == categoryNameToRemove
                                        }
                                        // 11. If the Category object exists, use detach(_:on:) to remove the relationship and delete the pivot.
                                        if let category = categoryToRemove {
                                            categoryResults.append(acronym.categories.detach(category, on: req))
                                        }
                                    }
                                    // 12. Flatten all the future category results. Transform the result to redirect to the updated acronym’s page.
                                    return categoryResults
                                        .flatten(on: req)
                                        .transform(to: req.redirect(to: "/acronyms/\(id)"))
                                })
                            })
        })
    }
    
    // This route extracts the acronym from the request’s parameter and calls delete(on:) on the acronym. The route then transforms the result to redirect the page to the home screen.
    func deleteAcronymHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(Acronym.self).delete(on: req)
            .transform(to: req.redirect(to: "/"))
    }
    
    // 1. Define a route handler for the login page that returns a future View.
    func loginHandler(_ req: Request) throws -> Future<View> {
        let context: LoginContext
        // 2. If the request contains the error parameter, create a context with loginError set to true.
        if req.query[Bool.self, at: "error"] != nil {
            context = LoginContext(loginError: true)
        } else {
            context = LoginContext()
        }
        // 3. Render the login.leaf template, passing in the context.
        return try req.view().render("login", context)
    }
    
    // 1. Define the route handler that decodes LoginPostData from the request and returns Future<Response>.
    func loginPostHandler(_ req: Request, userData: LoginPostData) throws -> Future<Response> {
        // 2. Call authenticate(username:password:using:on:). This checks the username and password against the database and verifies the BCrypt hash. This function returns a nil user in a future if there’s an issue authenticating the user.
        return User.authenticate(username: userData.username,
                                 password: userData.password,
                                 using: BCryptDigest(),
                                 on: req).map(to: Response.self, { (user) in
                                    // 3. Verify authenticate(username:password:using:on:) returned an authenticated user; otherwise, redirect back to the login page to show an error.
                                    guard let user = user else {
                                        return req.redirect(to: "/login?error")
                                    }
                                    // 4. Authenticate the request’s session. This saves the authenticated User into the request’s session so Vapor can retrieve it in later requests. This is how Vapor persists authentication when a user logs in.
                                    try req.authenticateSession(user)
                                    // 5. Redirect to the homepage after the login succeeds.
                                    return req.redirect(to: "/")
        })
    }
    
    // 1. Define a route handler that simply returns Response. There’s no asynchronous work in this function so it doesn’t need to return a future.
    func logoutHandler(_ req: Request) throws -> Response {
       // 2. Call unauthenticateSession(_:) on the request. This deletes the user from the session so it can’t be used to authenticate future requests.
        try req.unauthenticateSession(User.self)
        // 3. Return a redirect to the index page.
        return req.redirect(to: "/")
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]?
    let userLoggedIn: Bool
    let showCookieMessage: Bool
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
    let categories: Future<[Category]>
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
}

struct AllUsersContext: Encodable {
    let title: String
    let users: [User]
}

struct AllCategoriesContext: Encodable {
    // 1. Define the page’s title for the template.
    let title = "All Categories"
    // 2. Define a future array of categories to display in the page.
    let categories: Future<[Category]>
}

struct CategoryContext: Encodable {
    // 1. A title for the page; you’ll set this as the category name.
    let title: String
    // 2. The category for the page. This isn’t Future<Category> since you need the category’s name to set the title. This means you’ll have to unwrap the future in your route handler.
    let category: Category
    // 3. The category’s acronyms, provided as a future.
    let acronyms: Future<[Acronym]>
}

struct CreateAcronymContext: Encodable {
    let title = "Create an Acronym"
    // Cross-Site Request Forgery (CSRF)
    let csrfToken: String
}

struct EditAcronymContext: Encodable {
    // 1. The title for the page: “Edit Acronym”.
    let title = "Edit Acronym"
    // 2. The acronym to edit.
    let acronym: Acronym
    // 3. A future array of users to display in the form.
//    let users: Future<[User]> No Longer required
    // 4. A flag to tell the template that the page is for editing an acronym.
    let editing = true
    let categories: Future<[Category]>
}

struct CreateAcronymData: Content {
    let short: String
    let long: String
    let categories: [String]?
    let csrfToken: String
}

struct LoginContext: Encodable {
    let title = "Log In"
    let loginError: Bool
    
    init(loginError: Bool = false) {
        self.loginError = loginError
    }
}

struct LoginPostData: Content {
    let username: String
    let password: String
}
