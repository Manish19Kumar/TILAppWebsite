import Vapor
import Fluent
import Authentication

struct AcronymsController: RouteCollection {
    func boot(router: Router) throws {
        let acronymsRoutes = router.grouped("api", "acronyms")
//        acronymsRoutes.post(Acronym.self, use: createHandler)
        /*
         // Without Authentication
        acronymsRoutes.put(Acronym.parameter, use: updateHandler)
        acronymsRoutes.delete(Acronym.parameter, use: deleteHandler)
        acronymsRoutes.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
        acronymsRoutes.delete(Acronym.parameter, "categories", Category.parameter, use: removeCategoriesHandler) */
        
        acronymsRoutes.get("search", use: searchHandler)
        acronymsRoutes.get("first", use: getFirstHandler)
        acronymsRoutes.get("sorted", use: sortedHandler)
        acronymsRoutes.get(Acronym.parameter, "user", use: getUserHandler)
        acronymsRoutes.get(use: getAllHandler)
        acronymsRoutes.get(Acronym.parameter, use: getHandler)
        acronymsRoutes.get(Acronym.parameter, "categories", use: getCategoriesHandler)

        /*
         // Basic protection
         // 1. Instantiate a basic authentication middleware which uses BCryptDigest to verify passwords. Since User conforms to BasicAuthenticatable, this is available as a static function on the model.
        let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
        // 2. Create an instance of GuardAuthenticationMiddleware which ensures that requests contain valid authorization.
        let guardAuthMiddleware = User.guardAuthMiddleware()
        // 3. Create a middleware group which uses basicAuthMiddleware and guardAuthMiddleware.
        let protected = acronymsRoutes.grouped(basicAuthMiddleware, guardAuthMiddleware)
        // 4. Connect the “create acronym” path to createHandler(_:acronym:) through this middleware group.
        protected.post(AcronymCreateData.self, use: createHandler)
 */
        // Token based protection
        // 1. Create a TokenAuthenticationMiddleware for User. This uses BearerAuthenticationMiddleware to extract the bearer token out of the request. The middleware then converts this token into a logged in user.
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        
        // 2. Create a route group using tokenAuthMiddleware and guardAuthMiddleware to protect the route for creating an acronym with token authentication.
        let tokenAuthGroup = acronymsRoutes.grouped(tokenAuthMiddleware,
                                                    guardAuthMiddleware)
        
        // 3. Connect the “create acronym” path to createHandler(_:data:) through this middleware group using the new AcronymCreateData.
        tokenAuthGroup.post(AcronymCreateData.self, use: createHandler)
        
        // Adding authentication to deletion and posting
        tokenAuthGroup.delete(Acronym.parameter, use: deleteHandler)
        tokenAuthGroup.put(Acronym.parameter, use: updateHandler)
        tokenAuthGroup.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
        tokenAuthGroup.delete(Acronym.parameter, "categories", Category.parameter, use: removeCategoriesHandler)
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req).all()
    }
    
    // Old method without user token
//    func createHandler(_ req: Request, acronym: Acronym) throws -> Future<Acronym> {
//        return acronym.save(on: req)
//    }
    
    // New method withod user token
    // 1. Define a route handler that accepts AcronymCreateData as the request body.
    func createHandler(_ req: Request, data: AcronymCreateData) throws -> Future<Acronym> {
        // 2. Get the authenticated user from the request.
        let user = try req.requireAuthenticated(User.self)
        // 3. Create a new Acronym using the data from the request and the authenticated user.
        let acronym = try Acronym(
            short: data.short,
            long: data.long,
            userID: user.requireID())
        // 4. Save and return the acronym.
        return acronym.save(on: req)
    }
    
    func getHandler(_ req: Request) throws -> Future<Acronym> {
        return try req.parameters.next(Acronym.self)
    }
  
    // Previous method without token functionality
//    func updateHandler(_ req: Request) throws -> Future<Acronym> {
//        return try flatMap(to: Acronym.self,
//                           req.parameters.next(Acronym.self),
//                           req.content.decode(Acronym.self)) { acronym, updatedAcronym in
//                            acronym.short = updatedAcronym.short
//                            acronym.long = updatedAcronym.long
//                            acronym.userID = updatedAcronym.userID
//                            return acronym.save(on: req)
//        }
//    }
    // New method with token functionality
    func updateHandler(_ req: Request) throws -> Future<Acronym> {
        // 1. Decode the request’s data to AcronymCreateData since request no longer contains the user’s ID in the post data.
        return try flatMap(to: Acronym.self,
                           req.parameters.next(Acronym.self),
                           req.content.decode(AcronymCreateData.self), { (acronym, updateData) in
                            acronym.short = updateData.short
                            acronym.long = updateData.long
                            
                            // 2. Get the authenticated user from the request and use that to update the acronym.
                            let user = try req.requireAuthenticated(User.self)
                            acronym.userID = try user.requireID()
                            return acronym.save(on: req)
        })
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(Acronym.self).delete(on: req).transform(to: HTTPStatus.noContent)
    }
    
    func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
        guard let searchTerm = req.query[String.self, at: "term"] else {
            throw Abort(.badRequest)
        }
        return Acronym.query(on: req).group(.or) { or in
            or.filter(\.short == searchTerm)
            or.filter(\.long == searchTerm)
            }.all()
    }
    
    func getFirstHandler(_ req: Request) throws -> Future<Acronym> {
        return Acronym.query(on: req).first().map(to: Acronym.self) { acronym in
            guard let acronym = acronym else {
                throw Abort(.notFound)
            }
            return acronym
        }
    }
    
    func sortedHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req).sort(\.short, .ascending).all()
    }
    
    // Earlier method returning all the fields for User
//    func getUserHandler(_ req: Request) throws -> Future<User> {
//        return try req.parameters.next(Acronym.self).flatMap(to: User.self) { acronym in
//            acronym.user.get(on: req)
//        }
//    }
    // 1. Change the return type of the method to Future<User.Public>.
    func getUserHandler(_ req: Request) throws -> Future<User.Public> {
        // 2. Change the parameter of flatMap(to:) to User.Public.self.
        return try req.parameters.next(Acronym.self).flatMap(to: User.Public.self, { (acronym) in
            // 3. Call convertToPublic() on the acronym’s user to return a public user.
            acronym.user.get(on: req).convertToPublic()
        })
    }
    
    func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self), req.parameters.next(Category.self)) { acronym, category in
            return acronym.categories.attach(category, on: req).transform(to: .created)
        }
    }
    
    func getCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
        return try req.parameters.next(Acronym.self).flatMap(to: [Category].self) { acronym in
            try acronym.categories.query(on: req).all()
        }
    }
    
    func removeCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(to: HTTPStatus.self, req.parameters.next(Acronym.self), req.parameters.next(Category.self)) { acronym, category in
            return acronym.categories.detach(category, on: req).transform(to: .noContent)
        }
    }
}

struct AcronymCreateData: Content {
    let short: String
    let long: String
}

