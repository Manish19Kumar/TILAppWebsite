import Vapor
import Crypto

struct UsersController: RouteCollection {
    func boot(router: Router) throws {
        let usersRoute = router.grouped("api", "users")
//        usersRoute.post(User.self, use: createHandler)
        usersRoute.get(use: getAllHandler)
        usersRoute.get(User.parameter, use: getHandler)
        usersRoute.get(User.parameter, "acronyms", use: getAcronymsHandler)
        
        // 1. Create a protected route group using HTTP basic authentication, as you did for creating an acronym. This doesn’t use GuardAuthenticationMiddleware since requireAuthenticated(_:) throws the correct error if a user isn’t authenticated.
        let basicAuthMiddleware = User.basicAuthMiddleware(using: BCryptDigest())
        let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
        // 2. Connect /api/users/login to loginHandler(_:) through the protected group.
        basicAuthGroup.post("login", use: loginHandler)
        
        // Allowing only authenticated users to create new users
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthGroup = usersRoute.grouped(
            tokenAuthMiddleware,
            guardAuthMiddleware
        )
        tokenAuthGroup.post(User.self, use: createHandler)
    }
    
    func createHandler(_ req: Request, user: User) throws -> Future<User.Public> {
        user.password = try BCrypt.hash(user.password)
        return user.save(on: req).convertToPublic()
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[User.Public]> {
        return User.query(on: req).decode(data: User.Public.self).all()
    }
    
    func getHandler(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(User.self).convertToPublic()
    }
    
    func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
        return try req.parameters.next(User.self).flatMap(to: [Acronym].self) { user in
            try user.acronyms.query(on: req).all()
        }
    }
    
    // 1. Define a route handler for logging a user in.
    func loginHandler(_ req: Request) throws -> Future<Token> {
        // 2. Get the authenticated user from the request. You’ll protect this route with the HTTP basic authentication middleware. This saves the user’s identity in the request’s authentication cache, allowing you to retrieve the user object later. requireAuthenticated(_:) throws an authentication error if there’s no authenticated user.
        let user = try req.requireAuthenticated(User.self)
        // 3. Create a token for the user.
        let token = try Token.generate(for: user)
        // 4. Save and return the token.
        return token.save(on: req)
    }
}

