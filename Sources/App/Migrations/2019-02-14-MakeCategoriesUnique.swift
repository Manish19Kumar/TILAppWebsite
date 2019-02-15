
import FluentPostgreSQL
import Vapor

// 1. Define a new type, MakeCategoriesUnique, that conforms to Migration.
struct makeCategoriesUnique: Migration {
    // 2. As required by Migration, define your database type with a typealias.
    typealias Database = PostgreSQLDatabase
    
    // 3. Define the required prepare(on:).
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        // 4. Since Category already exists in your database, use update(_:on:closure:) to modify the database
        return Database.update(Category.self,
                               on: conn,
                               closure: { (builder) in
                                // 5. Inside the closure, use unique(on:) to add a new unique index corresponding to the key path \.name.
                                builder.unique(on: \.name)
        })
    }
    
    //
    static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
        //
        return Database.update(Category.self,
                               on: conn,
                               closure: { (builder) in
                                //
                                builder.deleteUnique(from: \.name)
        })
    }
}
