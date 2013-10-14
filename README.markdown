# Fork of activerecord-import

This repo is a fork of https://github.com/zdennis/activerecord-import, and specifically written to add some kind of
:on_uplicate_key_update for a postgresql database. __Not tested very well, use at own risk!__

Syntax is similar to the original, ie

```
MyModel.import(columns, values, :validate => false,
  :on_duplicate_key_update => [:field1, :field2, :field3],
  :index_keys => [:fieldA, :fieldB]
)
```

- The :on_duplicate_key_update array are the fields to be updated when an existing record is found
- The :index_keys array are the fields which determine if there is an existing record. This example shows a unique index on the :fieldA and :fieldB fields.

From my rudimentary understanding of postgres, I believe you can produce something similar to the native MySQL 'ON DUPLICATE KEY UPDATE' construct in one of 4 ways:

1. Using Merge / Upsert
2. Using CTE (Common Table Expressions)
3. Using a custom Trigger / Function / RULE
4. An UPDATE query followed by an INSERT ... WHERE NOT EXISTS query

__This fork implements method 4.__ I chose this as I found it simplest to implement and I preferred to keep this at the application code level rather than at the database level.

Using the example above, it will execute SQL similar to:

```
// this line will fail silently with no side effects if no records are found
UPDATE table SET field1 = 1, field2 = 2, field3 = 3 WHERE fieldA = A AND fieldB = B;

// this line will insert a new record if no records are found
INSERT INTO table
  SELECT field1, field2, field3, field4, ...
  WHERE NOT EXISTS (
    SELECT 1 FROM table WHERE fieldA = A AND fieldB = B
  )
```





# activerecord-import

activerecord-import is a library for bulk inserting data using ActiveRecord.

### Rails 4.0

Use activerecord-import 0.4.0 or higher.

### Rails 3.1.x up to, but not including 4.0

Use the latest in the activerecord-import 0.3.x series.

### Rails 3.0.x up to, but not including 3.1

Use activerecord-import 0.2.11. As of activerecord-import 0.3.0 we are relying on functionality that was introduced in Rails 3.1. Since Rails 3.0.x is no longer a supported version of Rails we have decided to drop support as well.

### For More Information

For more information on activerecord-import please see its wiki: https://github.com/zdennis/activerecord-import/wiki

# License

This is licensed under the ruby license.

# Author

Zach Dennis (zach.dennis@gmail.com)

# Contributors

* Blythe Dunham
* Gabe da Silveira
* Henry Work
* James Herdman
* Marcus Crafter
* Thibaud Guillaume-Gentil
* Mark Van Holstyn
* Victor Costan
