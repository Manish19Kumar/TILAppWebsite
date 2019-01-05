import Vapor
import Leaf

// 1. Declare a new WebsiteController type that conforms to RouteCollection.
struct WebsiteController: RouteCollection {
    // 2. Implement boot(router:) as required by RouteCollection.
    func boot(router: Router) throws {
        // 3. Register indexHandler(_:) to process GET requests to the router’s root path, i.e., a request to /.
        router.get(use: indexHandler)
        
        router.get("acronyms", Acronym.parameter, use: acronymHandler)
    }
    
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
                let context = IndexContext(title: "Homepage", acronyms: acronymsData)
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
                        let context = AcronymContext(title: acronym.short,
                                                     acronym: acronym,
                                                     user: user)
                        return try req.view().render("acronym", context)
                    })
            })
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]?
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
}
