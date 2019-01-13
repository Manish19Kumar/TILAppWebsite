import Vapor
import FluentPostgreSQL

final class Category: Codable {
    var id: Int?
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

extension Category: PostgreSQLModel {}
extension Category: Content {}
extension Category: Migration {}
extension Category: Parameter {}

extension Category {
    var acronyms: Siblings<Category, Acronym, AcronymCategoryPivot> {
        return siblings()
    }
    static func addCategory(_ name: String, to acronym: Acronym, on req: Request) throws -> Future<Void> {
        // 1. Perform a query to search for a category with the provided name.
        return Category.query(on: req)
            .filter(\.name == name)
            .first()
            .flatMap(to: Void.self, { (foundCategory) in
                if let existingCategory = foundCategory {
                    // 2. If the category exists, set up the relationship and transform to result to Void. () is shorthand for Void().
                    return acronym.categories
                        .attach(existingCategory, on: req)
                        .transform(to: ())
                } else {
                    // 3. If the category doesn’t exist, create a new Category object with the provided name.
                    let category = Category(name: name)
                    // 4. Save the new category and unwrap the returned future.
                    return category.save(on: req)
                        .flatMap(to: Void.self, { (savedCategory) in
                            // 5. Set up the relationship and transform the result to Void.
                            return acronym.categories
                                .attach(savedCategory, on: req)
                                .transform(to: ())
                        })
                }
            })
    }
}

