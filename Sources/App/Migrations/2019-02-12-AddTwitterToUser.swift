
import FluentPostgreSQL
import Vapor

// 1. Define a new type, AddTwitterURLToUser, that conforms to Migration.
struct AddTwitterURLToUser: Migration {
    
    // 2. As required by Migration, define your database type with a typealias.
    typealias Database = PostgreSQLDatabase
    
    // 3. Define the required prepare(on:).
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        // 4. Since User already exists in your database, use update(_:on:closure:) to modify the database.
        return Database.update(User.self,
                               on: conn,
                               closure: { (builder) in
                                // 5. Inside the closure, use field(for:) to add a new field corresponding to the key path \.twitterURL.
                                builder.field(for: \.twitterURL)
        })
    }
    
    // 6. Define required revert(on:).
    static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
        // 7. Since you’re modifying an existing Model, you again use update(_:on:closure:) to remove the new field.
        return Database.update(User.self,
                               on: conn,
                               closure: { (builder) in
                                // 8. Inside the closure, use deleteField(for:) to remove the field corresponding to the key path \.twitterURL.
                                builder.deleteField(for: \.twitterURL)
        })
    }
}
