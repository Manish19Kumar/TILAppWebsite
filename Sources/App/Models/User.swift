import Foundation
import Vapor
import FluentPostgreSQL
import Authentication

final class User: Codable {
    var id: UUID?
    var name: String
    var username: String
    var password: String
    
    init(name: String, username: String, password: String) {
        self.name = name
        self.username = username
        self.password = password
    }
    
    final class Public: Codable {
        var id: UUID?
        var name: String
        var username: String
        
        init(id: UUID?, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
        }
    }
}

extension User: PostgreSQLUUIDModel {}
extension User: Content {}

extension User: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        // 1. Create the User table.
        return Database.create(self, on: connection, closure: { (builder) in
            // 2. Add all the columns to the User table using User’s properties.
            try addProperties(to: builder)
            // 3. Add a unique index to username on User.
            // User name becomes unique
            builder.unique(on: \.username)
        })
    }
}
extension User: Parameter {}
extension User.Public: Content {}

extension User {
    // 1. Define a method on User that returns User.Public.
    func convertToPublic() -> User.Public {
        // 2. Create a public version of the current object.
        return User.Public(id: id, name: name, username: username)
    }
}

// 1. Define an extension for Future<User>.
extension Future where T: User {
    // 2. Define a new method that returns a Future<User.Public>.
    func convertToPublic() -> Future<User.Public> {
        // 3. Unwrap the user contained in self.
        return self.map(to: User.Public.self, { (user) in
            // 4. Convert the User object to User.Public.
            return user.convertToPublic()
        })
    }
}

extension User {
    var acronyms: Children<User, Acronym> {
        return children(\.userID)
    }
}

// 1. Conform User to BasicAuthenticatable.
extension User: BasicAuthenticatable {
    // 2. Tell Vapor which property of User is the username.
    static let usernameKey: UsernameKey = \User.username
    // 3. Tell Vapor which property of User is the password.
    static let passwordKey: PasswordKey = \User.password
}

// 1. Conform User to TokenAuthenticatable. This allows a token to authenticate a user.
extension User: TokenAuthenticatable {
    // 2. Tell Vapor what type a token is.
    typealias TokenType = Token
}

// 1. Define a new type that conforms to Migration.
struct AdminUser: Migration {
    // 2. Define which database type this migration is for.
    typealias Database = PostgreSQLDatabase
    
    // 3. Implement the required prepare(on:).
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        // 4. Create a password hash and terminate with a fatal error if this fails.
        let password = try? BCrypt.hash("password")
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user")
        }
        
        // 5. Create a new user with the name Admin, username admin and the hashed password.
        let user = User(
            name: "Admin",
            username: "admin",
            password: hashedPassword)
        // 6. Save the user and transform to result to Void, the return type of prepare(on:).
        return user.save(on: connection).transform(to: ())
    }
    
    // 7. Implement the required revert(on:). .done(on:) returns a pre-completed Future<Void>.
    static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return .done(on: connection)
    }
}

// 1. Conform User to PasswordAuthenticatable. This allows Vapor to authenticate users with a username and password when they log in. Since you’ve already implemented the necessary properties for PasswordAuthenticatable in BasicAuthenticatable, there’s nothing to do here.
extension User: PasswordAuthenticatable {
    
}

// 2. Conform User to SessionAuthenticatable. This allows the application to save and retrieve your user as part of a session.
extension User: SessionAuthenticatable {
    
}
