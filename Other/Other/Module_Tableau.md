This article describes how to create and use calculated fields in Tableau using an example.

You'll learn Tableau calculation concepts, as well as how to create and edit a calculated field. You will also learn how to work with the calculation editor, and use a calculated field in the view.

If you're new to Tableau calculations or to creating calculated fields in Tableau, this is a good place to start.

Why Use Calculated Fields
Calculated fields allow you to create new data from data that already exists in your data source. When you create a calculated field, you are essentially creating a new field (or column) in your data source, the values or members of which are determined by a calculation that you control. This new calculated field is saved to your data source in Tableau, and can be used to create more robust visualizations. But don't worry: your original data remains untouched.

You can use calculated fields for many, many reasons. Some examples might include:

To segment data
To convert the data type of a field, such as converting a string to a date.
To aggregate data
To filter results
To calculate ratios


Applies to: Tableau Cloud, Tableau Desktop, Tableau Public, Tableau Server
This article describes how to create and format calculations in Tableau. It lists the basic components of calculations and explains the proper syntax for each.

Calculation building blocks
There are four basic components to calculations in Tableau:

Functions: Statements used to transform the values or members in a field.
Functions require arguments, or specific pieces of information. Depending on the function, arguments can be fields, literals, parameters, or nested functions.
Fields: Dimensions or measures from your data source.
Operators: Symbols that denote an operation.
Literal expressions: Constant values that are hardcoded, such as "High" or 1,500.
Not all calculations need to contain all four components. Additionally, calculations can contain:

Parameters: Placeholder variables that can be inserted into calculations to replace constant values. For more information on parameters, see Create Parameters.
Comments: Notes about a calculation or its parts, not included in the computation of the calculation.
For more information about how to use and format each of these components in a calculation, see the following sections.

Example calculation explained
For example, consider the following calculation, which adds 14 days to a date ([Initial Visit]). A calculation like this could be useful for automatically finding the date for a two-week followup.

DATEADD
(
'day'
, 
14
, 
[Initial Visit
)
The components of this calculation can be broken down as:

Function: DATEADD, which requires three arguments.
date_part ('day')
interval (14)
date ([Initial Visit]).
Field: [Initial Visit]
Operators: n/a
Literal expressions:
String literal: 'day'
Numeric literal: 14
In this example, the hardcoded constant 14 could be replaced with a parameter, which would allow the user to select how many days out to look for a followup appointment.

DATEADD
(
'day'
, 
[How many days out?]
, 
[Initial Visit
)
At a glance: calculation syntax
Components	Syntax	Example
Functions

See Tableau Functions (Alphabetical)(Link opens in a new window) or Tableau Functions (by Category) for examples of how to format all functions in Tableau.

SUM(expression)

Fields

A field in a calculation is often surrounded by brackets [ ].

See Field syntax for more information.

[Category]

Operators

+, -, *, /, %, ==, =, >, <, >=, <=, !=, <>, ^, AND, OR, NOT, ( ).

See Operator syntax for information on the types of operators you can use in Tableau calculation and the order they are performed in a formula.

[Price]*(1-[discount])

Literal expressions

Numeric literals are written as numbers.

String literals are written with quotation marks.

Date literals are written with the # symbol.

Boolean literals are written as either true or false.

Null literals are written as null.

See Literal expression syntax for more information.

1.3567

"Unprofitable"

#August 22, 2005#

true

Null

Parameters

A parameter in a calculation is surrounded by brackets [ ], like a field. See Create Parameters for more information.

[Bin Size]

Comments

To enter a comment in a calculation, type two forward slashes //. See Add comments to a calculation for more information.

Multi-line comments can be added by typing /* to start the comment and */ to end it.

SUM([Sales]) / SUM([Profit])

/*John's calculation

To be used for profit ratio

Do not edit*/

Calculation syntax in detail
See the following sections to learn more about the different components of Tableau calculations and how to format them to work in Tableau.

Function syntax
Functions are the main components of a calculation and can be used for various purposes.

Every function in Tableau requires a particular syntax. For example, the following calculation uses two functions, LEN and LEFT, as well as several logical operators (IF, THEN, ELSE, END, and > ).

IF LEN([Name])> 5 THEN LEFT([Name],5) ELSE [Name] END

LEN takes a single argument, such as LEN([Name]) which returns the number of characters (that is, the length) for each value in the Name field.
LEFT takes two arguments, a field and a number, such as LEFT([Name], 5) which returns the first five characters from each value in the Name field starting from the left.
The logical operators IF , THEN, ELSE, and END work together to create a logical test.
This calculation evaluates the length of a name and, if it's more than five characters, returns only the first five. Otherwise, it returns the entire name.

In the calculation editor, functions are colored blue.

Use the calculation editor reference pane
You can look up how to use and format a particular function at any time. To open the list of functions in Tableau:

Select Analysis > Create Calculated Field.
In the Calculation Editor that opens, click the expand (triangle) icon located on the right edge of the editor.
A list of functions appears for you to browse. When you select a function from the list, the section on the far right updates with information about that function's required syntax (1), its description (2), and one or more examples (3).

Functions menu.

Using multiple functions in a calculation
You can use more than one function in a calculation. For example:

ZN(SUM([Order Quantity])) - WINDOW_AVG(SUM([Order Quantity]))

There are three functions in the calculation: ZN, SUM, and WINDOW_AVG. The ZN function and the WINDOW_AVG function are separated with the subtraction operator (-).

A function can also be part of another function (or, nested), as is the case with the ZN(SUM([Order Quantity])) portion of the example above. In this case, the SUM of Order Quantity is computed before the ZN function because it is inside parentheses. For more information on why, see Parentheses.

Field syntax
Fields can be inserted into your calculations. Often, a function's syntax indicates where a field should be inserted into the calculation. For example: SUM(expression).

Field names should be encompassed by brackets [ ] in a calculation when the field name contains a space or is not unique. For example, [Sales Categories].

The type of function you use determines the type of field you use. For example, with the SUM function, you can insert a numerical field, but you cannot insert a date field. For more information, see Understanding data types in calculations.

The fields you choose to include in your calculations also depend on the purpose of calculation. For example, if you want to calculate profit ratio your calculation will use the Sales and Profit fields from your data source:

SUM([Sales])/SUM([Profit])

To add a field to a calculation, do one of the following:

Drag it from the Data pane or the view and drop it in the calculation editor.
In the Calculation Editor, type the field name. Note: The Calculation Editor attempts to auto-complete field names.
Functions and operators in a calculated field.

Fields are colored orange in Tableau calculations.

Operator syntax
To create calculations, you need to understand the operators supported by Tableau. This section discusses the basic operators that are available and the order (precedence) they are performed.

Operators are colored black in Tableau calculations.

+ (addition)
The + operator means addition when applied to numbers and concatenation when applied to strings. When applied to dates, it can be used to add a number of days to a date.

For example:

7 + 3
Profit + Sales
'abc' + 'def' = 'abcdef'
#April 15, 2024# + 15 = #April 30, 2024#
– (subtraction)
The - operator means subtraction when applied to numbers and negation if applied to an expression. When applied to dates, it can be used to subtract a number of days from a date. Hence, it can also be used to calculate the difference in days between two dates.

For example:

7 - 3
Profit - Sales
-(7+3) = -10
#April 16, 2024# - 15 = #April 1, 2024#
#April 15, 2024# - #April 8, 2024# = 7
* (multiplication)
The * operator means numeric multiplication.

For example: 5 * 4 = 20

/ (division)
The / operator means numeric division.

For example: 20 / 4 = 5

% (modulo)
The % operator returns the remainder of a division operation. Modulo can only operate on integers.

For example: 9 % 2 = 1. (Because 2 goes into 9 four times with a remainder of 1.)

==, =, >, <, >=, <=, !=, <> (comparisons)
These are the basic comparison operators that can be used in expressions. Their meanings are as follows:

== or = (equal to)
> (greater than)
< (less than)
>= (greater than or equal to)
<= (less than or equal to)
!= or <> (not equal to)
Each operator compares two numbers, dates, or strings and returns either TRUE, FALSE, or NULL.

^ (power)
This symbol is equivalent to the POWER function. It raises a number to the specified power.

For example: 6^3 = 216

AND
This is a logical operator. An expression or a boolean must appear on either side of it.

For example: IIF(Profit =100 AND Sales =1000, "High", "Low")

See AND in Logical Functions for more information.

OR
This is a logical operator. An expression or a boolean must appear on either side of it.

For example: IIF(Profit =100 OR Sales =1000, "High", "Low")

See OR in Logical Functions for more information.

NOT
This is a logical operator. It can be used to negate another boolean or an expression. For example,

IIF(NOT(Sales = Profit),"Not Equal","Equal")

Other Operators
CASE, ELSE, ELSEIF, IF, THEN, WHEN, and END are also operators used for Logical Functions.

Operator precedence
All operators in a calculation are evaluated in a specific order. For example, 2*1+2 is equal to 4 and not equal to 6, because multiplication is performed before addition (the * operator is always evaluated before the + operator).

If two operators have the same precedence (such as addition and subtraction (+ or -) they are evaluated from left to right in the calculation.

Parentheses can be used to change the order of precedence. See the Parentheses section for more information.

Precedence	Operator
1	– (negate)
2	^ (power)
3	*, /, %
4	+, –
5	==, =, >, <, >=, <=, !=, <>
6	NOT
7	AND
8	OR
Parentheses
Parentheses can be used as needed to force an order of precedence. Operators that appear within parentheses are evaluated before those outside of parentheses, starting from the innermost parentheses and moving outward.

For example, (1 + (2*2+1)*(3*6/3) ) = 31 because the operators within the innermost parentheses are performed first. The calculation is calculated in the following order:

(2*2+1) = 5
(3*6/3) = 6
(1+ 5*6) = 31
Literal expression syntax
This section describes the proper syntax for using literal expressions in Tableau calculations. A literal expression signifies a constant value that is represented as is. When you are using functions you will sometimes want to use literal expressions to represent numbers, strings, dates, and more.

For example, you may have a function where your input is a date. Rather than type "May 1, 2005", which would be interpreted a string, you would type #May 1, 2005#. This is equivalent to using a date function to convert the argument from a string to a date (refer to Date Functions).

You can use numeric, string, date, boolean, and null literals in Tableau calculations. Each type, and how to format them, are described below.

Literal expressions are colored black and gray in Tableau calculations.

Numeric Literals
A numeric literal is written as a number. For example, to input the number one as a numeric literal, enter 1. If you want to input the number 0.25 as a numeric literal, enter 0.25.

String Literals
A string literal can be written either using 'single quote' or "double quote".

If your string has a single or double quote within it, use the other option for the outermost string literals.

For example, to input the string "cat" as a string literal, type'"cat"'. For 'cat' type "'cat'". If you want to type the string She's my friend as a string literal, use double quotes for the literals, as in "She's my friend."

Date Literals
Date literals are signified by the pound symbol (#). To input the date "August 22, 2005" as a literal date, enter the ISO formatted date, #2005-08-22#.

Boolean Literals
Boolean literals are written as either true or false. To input "true" as a boolean literal, enter true.

Null Literals
Null literals are written as Null. To input "Null" as a Null literal, enter Null.

Add parameters to a calculation
Parameters are placeholder variables that can be inserted into calculations to replace constant values. When you use a parameter in a calculation, you can then expose a parameter control in a view or dashboard to allow users to dynamically change the value.

For details, see Use a parameter .

Parameters are colored purple in Tableau calculations.

Add comments to a calculation
You can add comments to a calculation to make notes about it or its parts. Comments are not included in the computation of the calculation.

To add a comment to a calculation, type two forward slash (//) characters.

For example:

SUM([Sales])/SUM([Profit]) //My calculation

In this example, //My calculation is a comment.

A comment starts at the two forward slashes (//) and goes to the end of the line. To continue with your calculation, you must start a new line.

A multi-line comment can be written by starting the comment with a forward slash followed by an asterisk (/*), and closed with an asterisk followed by a forward slash (*/). For example:

SUM([Sales])/SUM([Profit])
/* This calculation is
used for profit ratio.
Do not edit */

Comments are colored gray in Tableau calculations.

Understanding data types in calculations
If you create calculated fields, you need to know how to use and combine the different data types(Link opens in a new window) in calculations. Many functions that are available to you when you define a calculation only work when they are applied to specific data types.

For example, the DATEPART() function can accept only a date/datetime data type as an argument. You can enter DATEPART('year',#2024-04-15#) and expect a valid result: 2024. You cannot enter DATEPART('year',"Tom Sawyer") and expect a valid result. In fact, this example returns an error because "Tom Sawyer" is a string, not a date/datetime.

Note: Although Tableau attempts to fully validate all calculations, some data type errors cannot be found until the query is run against the database. These issues appear as error dialogs at the time of the query rather than in the calculation dialog box.

The data types supported by Tableau are described below. Refer to Type Conversion to learn about converting from one data type to another.

String
A sequence of zero or more characters. For example, "Wisconsin", "ID-44400", and "Tom Sawyer" are all strings. Strings are recognized by single or double quotes. The quote character itself can be included in a string by repeating it. For example, 'O''Hanrahan'.

Date/Datetime
A date or a datetime. For example "January 23, 1972" or "January 23, 1972 12:32:00 AM". If you would like a date written in long-hand style to be interpreted as a date/datetime, place the # sign on either side of it. For instance, "January 23, 1972" is treated as a string data type but #January 23, 1972# is treated as a date/datetime data type.

Number
Numerical values in Tableau can be either integers or floating-point numbers.

With floating-point numbers, results of some aggregations may not always be exactly as expected. For example, you may find that the SUM function returns a value such as -1.42e-14 for a field of numbers that you know should sum to exactly 0. This happens because the Institute of Electrical and Electronics Engineers (IEEE) 754 floating-point standard requires that numbers be stored in binary format, which means that numbers are sometimes rounded at extremely fine levels of precision. You can eliminate this potential distraction by formatting the number to show fewer decimal places. For more information, see ROUND in Number functions available in Tableau.

Operations that test floating point values for equality can behave unpredictably for the same reason. Such comparisons can occur when using level of detail expressions as dimensions, in categorical filtering, creating ad-hoc groups, creating IN/OUT sets, and with data blending.

Note: The largest signed 64-bit integer is 9,223,372,036,854,775,807. When connecting to a new data source, any column with data type set to Number (whole) can accommodate values up to this limit; for larger values, because Number (whole) does not use floating-points, Tableau displays "Null." When the data type is set to Number (decimal), larger values can be accommodated.

Boolean
A field that contains the values TRUE or FALSE. An unknown value arises when the result of a comparison is unknown. For example, the expression 7 > Null yields unknown. Unknown booleans are automatically converted to Null.

ormatting Calculations in Tableau
Applies to: Tableau Cloud, Tableau Desktop, Tableau Public, Tableau Server
This article describes how to create and format calculations in Tableau. It lists the basic components of calculations and explains the proper syntax for each.

Calculation building blocks
There are four basic components to calculations in Tableau:

Functions: Statements used to transform the values or members in a field.
Functions require arguments, or specific pieces of information. Depending on the function, arguments can be fields, literals, parameters, or nested functions.
Fields: Dimensions or measures from your data source.
Operators: Symbols that denote an operation.
Literal expressions: Constant values that are hardcoded, such as "High" or 1,500.
Not all calculations need to contain all four components. Additionally, calculations can contain:

Parameters: Placeholder variables that can be inserted into calculations to replace constant values. For more information on parameters, see Create Parameters.
Comments: Notes about a calculation or its parts, not included in the computation of the calculation.
For more information about how to use and format each of these components in a calculation, see the following sections.

Example calculation explained
For example, consider the following calculation, which adds 14 days to a date ([Initial Visit]). A calculation like this could be useful for automatically finding the date for a two-week followup.

DATEADD
(
'day'
, 
14
, 
[Initial Visit
)
The components of this calculation can be broken down as:

Function: DATEADD, which requires three arguments.
date_part ('day')
interval (14)
date ([Initial Visit]).
Field: [Initial Visit]
Operators: n/a
Literal expressions:
String literal: 'day'
Numeric literal: 14
In this example, the hardcoded constant 14 could be replaced with a parameter, which would allow the user to select how many days out to look for a followup appointment.

DATEADD
(
'day'
, 
[How many days out?]
, 
[Initial Visit
)
At a glance: calculation syntax
Components	Syntax	Example
Functions

See Tableau Functions (Alphabetical)(Link opens in a new window) or Tableau Functions (by Category) for examples of how to format all functions in Tableau.

SUM(expression)

Fields

A field in a calculation is often surrounded by brackets [ ].

See Field syntax for more information.

[Category]

Operators

+, -, *, /, %, ==, =, >, <, >=, <=, !=, <>, ^, AND, OR, NOT, ( ).

See Operator syntax for information on the types of operators you can use in Tableau calculation and the order they are performed in a formula.

[Price]*(1-[discount])

Literal expressions

Numeric literals are written as numbers.

String literals are written with quotation marks.

Date literals are written with the # symbol.

Boolean literals are written as either true or false.

Null literals are written as null.

See Literal expression syntax for more information.

1.3567

"Unprofitable"

#August 22, 2005#

true

Null

Parameters

A parameter in a calculation is surrounded by brackets [ ], like a field. See Create Parameters for more information.

[Bin Size]

Comments

To enter a comment in a calculation, type two forward slashes //. See Add comments to a calculation for more information.

Multi-line comments can be added by typing /* to start the comment and */ to end it.

SUM([Sales]) / SUM([Profit])

/*John's calculation

To be used for profit ratio

Do not edit*/

Calculation syntax in detail
See the following sections to learn more about the different components of Tableau calculations and how to format them to work in Tableau.

Function syntax
Functions are the main components of a calculation and can be used for various purposes.

Every function in Tableau requires a particular syntax. For example, the following calculation uses two functions, LEN and LEFT, as well as several logical operators (IF, THEN, ELSE, END, and > ).

IF LEN([Name])> 5 THEN LEFT([Name],5) ELSE [Name] END

LEN takes a single argument, such as LEN([Name]) which returns the number of characters (that is, the length) for each value in the Name field.
LEFT takes two arguments, a field and a number, such as LEFT([Name], 5) which returns the first five characters from each value in the Name field starting from the left.
The logical operators IF , THEN, ELSE, and END work together to create a logical test.
This calculation evaluates the length of a name and, if it's more than five characters, returns only the first five. Otherwise, it returns the entire name.

In the calculation editor, functions are colored blue.

Use the calculation editor reference pane
You can look up how to use and format a particular function at any time. To open the list of functions in Tableau:

Select Analysis > Create Calculated Field.
In the Calculation Editor that opens, click the expand (triangle) icon located on the right edge of the editor.
A list of functions appears for you to browse. When you select a function from the list, the section on the far right updates with information about that function's required syntax (1), its description (2), and one or more examples (3).

Functions menu.

Using multiple functions in a calculation
You can use more than one function in a calculation. For example:

ZN(SUM([Order Quantity])) - WINDOW_AVG(SUM([Order Quantity]))

There are three functions in the calculation: ZN, SUM, and WINDOW_AVG. The ZN function and the WINDOW_AVG function are separated with the subtraction operator (-).

A function can also be part of another function (or, nested), as is the case with the ZN(SUM([Order Quantity])) portion of the example above. In this case, the SUM of Order Quantity is computed before the ZN function because it is inside parentheses. For more information on why, see Parentheses.

Field syntax
Fields can be inserted into your calculations. Often, a function's syntax indicates where a field should be inserted into the calculation. For example: SUM(expression).

Field names should be encompassed by brackets [ ] in a calculation when the field name contains a space or is not unique. For example, [Sales Categories].

The type of function you use determines the type of field you use. For example, with the SUM function, you can insert a numerical field, but you cannot insert a date field. For more information, see Understanding data types in calculations.

The fields you choose to include in your calculations also depend on the purpose of calculation. For example, if you want to calculate profit ratio your calculation will use the Sales and Profit fields from your data source:

SUM([Sales])/SUM([Profit])

To add a field to a calculation, do one of the following:

Drag it from the Data pane or the view and drop it in the calculation editor.
In the Calculation Editor, type the field name. Note: The Calculation Editor attempts to auto-complete field names.
Functions and operators in a calculated field.

Fields are colored orange in Tableau calculations.

Operator syntax
To create calculations, you need to understand the operators supported by Tableau. This section discusses the basic operators that are available and the order (precedence) they are performed.

Operators are colored black in Tableau calculations.

+ (addition)
The + operator means addition when applied to numbers and concatenation when applied to strings. When applied to dates, it can be used to add a number of days to a date.

For example:

7 + 3
Profit + Sales
'abc' + 'def' = 'abcdef'
#April 15, 2024# + 15 = #April 30, 2024#
– (subtraction)
The - operator means subtraction when applied to numbers and negation if applied to an expression. When applied to dates, it can be used to subtract a number of days from a date. Hence, it can also be used to calculate the difference in days between two dates.

For example:

7 - 3
Profit - Sales
-(7+3) = -10
#April 16, 2024# - 15 = #April 1, 2024#
#April 15, 2024# - #April 8, 2024# = 7
* (multiplication)
The * operator means numeric multiplication.

For example: 5 * 4 = 20

/ (division)
The / operator means numeric division.

For example: 20 / 4 = 5

% (modulo)
The % operator returns the remainder of a division operation. Modulo can only operate on integers.

For example: 9 % 2 = 1. (Because 2 goes into 9 four times with a remainder of 1.)

==, =, >, <, >=, <=, !=, <> (comparisons)
These are the basic comparison operators that can be used in expressions. Their meanings are as follows:

== or = (equal to)
> (greater than)
< (less than)
>= (greater than or equal to)
<= (less than or equal to)
!= or <> (not equal to)
Each operator compares two numbers, dates, or strings and returns either TRUE, FALSE, or NULL.

^ (power)
This symbol is equivalent to the POWER function. It raises a number to the specified power.

For example: 6^3 = 216

AND
This is a logical operator. An expression or a boolean must appear on either side of it.

For example: IIF(Profit =100 AND Sales =1000, "High", "Low")

See AND in Logical Functions for more information.

OR
This is a logical operator. An expression or a boolean must appear on either side of it.

For example: IIF(Profit =100 OR Sales =1000, "High", "Low")

See OR in Logical Functions for more information.

NOT
This is a logical operator. It can be used to negate another boolean or an expression. For example,

IIF(NOT(Sales = Profit),"Not Equal","Equal")

Other Operators
CASE, ELSE, ELSEIF, IF, THEN, WHEN, and END are also operators used for Logical Functions.

Operator precedence
All operators in a calculation are evaluated in a specific order. For example, 2*1+2 is equal to 4 and not equal to 6, because multiplication is performed before addition (the * operator is always evaluated before the + operator).

If two operators have the same precedence (such as addition and subtraction (+ or -) they are evaluated from left to right in the calculation.

Parentheses can be used to change the order of precedence. See the Parentheses section for more information.

Precedence	Operator
1	– (negate)
2	^ (power)
3	*, /, %
4	+, –
5	==, =, >, <, >=, <=, !=, <>
6	NOT
7	AND
8	OR
Parentheses
Parentheses can be used as needed to force an order of precedence. Operators that appear within parentheses are evaluated before those outside of parentheses, starting from the innermost parentheses and moving outward.

For example, (1 + (2*2+1)*(3*6/3) ) = 31 because the operators within the innermost parentheses are performed first. The calculation is calculated in the following order:

(2*2+1) = 5
(3*6/3) = 6
(1+ 5*6) = 31
Literal expression syntax
This section describes the proper syntax for using literal expressions in Tableau calculations. A literal expression signifies a constant value that is represented as is. When you are using functions you will sometimes want to use literal expressions to represent numbers, strings, dates, and more.

For example, you may have a function where your input is a date. Rather than type "May 1, 2005", which would be interpreted a string, you would type #May 1, 2005#. This is equivalent to using a date function to convert the argument from a string to a date (refer to Date Functions).

You can use numeric, string, date, boolean, and null literals in Tableau calculations. Each type, and how to format them, are described below.

Literal expressions are colored black and gray in Tableau calculations.

Numeric Literals
A numeric literal is written as a number. For example, to input the number one as a numeric literal, enter 1. If you want to input the number 0.25 as a numeric literal, enter 0.25.

String Literals
A string literal can be written either using 'single quote' or "double quote".

If your string has a single or double quote within it, use the other option for the outermost string literals.

For example, to input the string "cat" as a string literal, type'"cat"'. For 'cat' type "'cat'". If you want to type the string She's my friend as a string literal, use double quotes for the literals, as in "She's my friend."

Date Literals
Date literals are signified by the pound symbol (#). To input the date "August 22, 2005" as a literal date, enter the ISO formatted date, #2005-08-22#.

Boolean Literals
Boolean literals are written as either true or false. To input "true" as a boolean literal, enter true.

Null Literals
Null literals are written as Null. To input "Null" as a Null literal, enter Null.

Add parameters to a calculation
Parameters are placeholder variables that can be inserted into calculations to replace constant values. When you use a parameter in a calculation, you can then expose a parameter control in a view or dashboard to allow users to dynamically change the value.

For details, see Use a parameter .

Parameters are colored purple in Tableau calculations.

Add comments to a calculation
You can add comments to a calculation to make notes about it or its parts. Comments are not included in the computation of the calculation.

To add a comment to a calculation, type two forward slash (//) characters.

For example:

SUM([Sales])/SUM([Profit]) //My calculation

In this example, //My calculation is a comment.

A comment starts at the two forward slashes (//) and goes to the end of the line. To continue with your calculation, you must start a new line.

A multi-line comment can be written by starting the comment with a forward slash followed by an asterisk (/*), and closed with an asterisk followed by a forward slash (*/). For example:

SUM([Sales])/SUM([Profit])
/* This calculation is
used for profit ratio.
Do not edit */

Comments are colored gray in Tableau calculations.

Understanding data types in calculations
If you create calculated fields, you need to know how to use and combine the different data types(Link opens in a new window) in calculations. Many functions that are available to you when you define a calculation only work when they are applied to specific data types.

For example, the DATEPART() function can accept only a date/datetime data type as an argument. You can enter DATEPART('year',#2024-04-15#) and expect a valid result: 2024. You cannot enter DATEPART('year',"Tom Sawyer") and expect a valid result. In fact, this example returns an error because "Tom Sawyer" is a string, not a date/datetime.

Note: Although Tableau attempts to fully validate all calculations, some data type errors cannot be found until the query is run against the database. These issues appear as error dialogs at the time of the query rather than in the calculation dialog box.

The data types supported by Tableau are described below. Refer to Type Conversion to learn about converting from one data type to another.

String
A sequence of zero or more characters. For example, "Wisconsin", "ID-44400", and "Tom Sawyer" are all strings. Strings are recognized by single or double quotes. The quote character itself can be included in a string by repeating it. For example, 'O''Hanrahan'.

Date/Datetime
A date or a datetime. For example "January 23, 1972" or "January 23, 1972 12:32:00 AM". If you would like a date written in long-hand style to be interpreted as a date/datetime, place the # sign on either side of it. For instance, "January 23, 1972" is treated as a string data type but #January 23, 1972# is treated as a date/datetime data type.

Number
Numerical values in Tableau can be either integers or floating-point numbers.

With floating-point numbers, results of some aggregations may not always be exactly as expected. For example, you may find that the SUM function returns a value such as -1.42e-14 for a field of numbers that you know should sum to exactly 0. This happens because the Institute of Electrical and Electronics Engineers (IEEE) 754 floating-point standard requires that numbers be stored in binary format, which means that numbers are sometimes rounded at extremely fine levels of precision. You can eliminate this potential distraction by formatting the number to show fewer decimal places. For more information, see ROUND in Number functions available in Tableau.

Operations that test floating point values for equality can behave unpredictably for the same reason. Such comparisons can occur when using level of detail expressions as dimensions, in categorical filtering, creating ad-hoc groups, creating IN/OUT sets, and with data blending.

Note: The largest signed 64-bit integer is 9,223,372,036,854,775,807. When connecting to a new data source, any column with data type set to Number (whole) can accommodate values up to this limit; for larger values, because Number (whole) does not use floating-points, Tableau displays "Null." When the data type is set to Number (decimal), larger values can be accommodated.

Boolean
A field that contains the values TRUE or FALSE. An unknown value arises when the result of a comparison is unknown. For example, the expression 7 > Null yields unknown. Unknown booleans are automatically converted to Null.



### IMPORTANT 



HOW TO RESOLVE THIS ERROR 

If you've spent any time working with Tableau, you've likely encountered the dreaded "Cannot Mix Aggregate and Non-Aggregate Arguments" error. It's a VERY common stumbling block that can stop your data visualization and calculated business logic efforts in their tracks.

I've seen this error trip up even seasoned analysts and it often shows up while you are knee-deep in complex calculated field creation. But here's the thing: this error isn't just Tableau being difficult. It's actually pointing to a crucial concept in data analysis that, once understood, can take your Tableau skills to the next level.

In this guide, we'll:

Break down what this error really means
Explain why Tableau calls out this in calculated fields
Offer likely solutions to get your analysis back on track
By the end, you'll have a solid grasp on aggregation in Tableau, allowing you to create more powerful and accurate visualizations. Let's dive in.


Understanding Aggregation in Tableau
Before we tackle the 'mix aggregate and non-aggregate' error head-on, let's get clear on what aggregation means in Tableau.

At its core, aggregation is about summarizing data. It's taking a large set of values and condensing them into a single, meaningful number. Instead of looking at every individual sale your company made last year, aggregation lets you see the total sales for each quarter or the average daily revenue.

The ability of aggregation to "zoom out" on data is what makes Tableau so powerful for uncovering insights and trends—think of it as a pivot table on steroids.

Tableau comes equipped with a variety of aggregation functions. Here are some of the most commonly used:

SUM: Adds up all the values (e.g. total sales and expenses)
AVG (Average): Calculates the arithmetic mean (e.g. average order value)
COUNT: Tells how many rows (or distinct values) are in a field (e.g. # orders)
MIN/MAX: Finds the smallest/largest values (e.g. lowest/highest priced item)
MEDIAN: Determines the middle value in a sorted list. Unlike average, it's not skewed by extreme outliers.
PERCENTILE: Calculates a specified percentile within your dataset; crucial for understanding data distribution
Each of these functions gives you a different lens through which to view your data, allowing for nuanced analysis and visualization.


Two Faces of Data: Aggregated vs. Non-Aggregated
Here's where we get to the heart of our error message. In Tableau, you're often working with two types of data:

Aggregated Data: This is your summarized view. It's like looking at your data from 30,000 feet - you see the big picture, not the individual details.
Non-Aggregated Data: This is your ground-level view, showing every individual record or data row in all its transactional glory.
The "Cannot Mix Aggregate and Non-Aggregate" error pops up when you try to combine these two types of data in ways that Tableau doesn't allow. It's like comparing apples to apple pie - they're related but not directly comparable.  Understanding this distinction is key to working effectively in Tableau.


"Cannot Mix Aggregate & Non-Aggregate" Explained
Now that we've laid the aggregate vs. non-aggregate groundwork above let's tackle the error head-on. Why does Tableau throw this error, and when are you most likely to encounter it?

Tableau's insistence on separating aggregate and non-aggregate data isn't arbitrary. It's rooted in maintaining data integrity and preventing logical inconsistencies in your analysis. When you mix these two types of data, you're essentially trying to compare values at different levels of granularity, which can lead to misleading or nonsensical results.

Think of it this way: comparing total annual sales (an aggregate) to individual transactional product prices (non-aggregate) is like comparing the size of a forest to the height of a single tree. They're related but not directly comparable.

At its core, this error occurs because Tableau needs to maintain a consistent level of granularity in calculations. When you mix aggregate and non-aggregate data, you're asking Tableau to perform calculations that don't align with how the data is structured or grouped in your visualization.

This strict separation is actually a safeguard. It prevents you from accidentally creating visualizations or calculations that could misrepresent your data or lead to incorrect conclusions.

Common Scenarios That Trigger the Error
Let's look at some situations where you're likely to run into this error:

Mixing aggregated measures with dimensions: Attempt: SUM([Sales]) / [Product Category] Problem: You're trying to divide a sum (aggregate) by a category name (non-aggregate).
Comparing aggregates to constants: Attempt: IF SUM([Sales]) > 1000 THEN [Product Category] END Problem: You're comparing an aggregated value (SUM of Sales) to a non-aggregated field (Product Category).
Nested aggregations: Attempt: AVG(SUM([Sales])) Problem: You're trying to aggregate an already aggregated value.
Mixing aggregation levels in calculated fields: Attempt: [Total Sales] / [Sales] Problem: If [Total Sales] is already an aggregated calculated field, you're mixing aggregation levels.
Resolving Aggregate vs Non-Aggregate Errors
While this error can be frustrating, it's actually pushing you towards better data analysis practices. By forcing you to think about the level of detail in your calculations, Tableau is encouraging you to be more precise and intentional in how you work with your data.  With these techniques in your toolkit, you'll be able to navigate around this error and create more robust, accurate visualizations.

Remember, the goal isn't just to eliminate the error but to structure your data and calculations in a way that makes sense analytically.

Method 1: Aggregate the Non-Aggregated Field

Often, the simplest solution is to aggregate the non-aggregated field in your calculation.

Example: Instead of: SUM([Sales]) / [Price] Try: SUM([Sales]) / AVG([Price])

This approach ensures both parts of your calculation are at the same level of aggregation.

Method 2: Use Level of Detail (LOD) Expressions

LOD expressions are powerful tools for handling aggregation issues. They allow you to compute values at a specific level of detail, independent of the visualization's level.

Example: Instead of: IF SUM([Sales]) > 1000 THEN [Product Category] END Try: IF SUM([Sales]) > 1000 THEN {FIXED : MAX([Product Category])} END

The FIXED LOD expression ensures [Product Category] is aggregated at the same level as SUM([Sales]).  The output of an LOD will be an aggregate calculation - be sure you understand fundamentally how the logic is being performed.

Method 3: Utilize Table Calculations (if applicable)

Table calculations perform computations on the results of your query, allowing you to work around aggregation conflicts.

Example: Instead of directly comparing SUM([Sales]) to [Running Total], use a table calculation: RUNNING_SUM(SUM([Sales]))

This approach allows you to perform calculations on already aggregated data.

Method 4: Restructure Your Data Source

Sometimes, the issue stems from how your data is structured. Consider using a data blend or joining tables to pre-aggregate data at the correct level.

For instance, if you frequently need total sales by category, you might create a pre-aggregated table with this information, avoiding the need to mix aggregation levels in Tableau.


Best Practices to Avoid the Error
Prevention is often better than cure. Here are some best practices to minimize encounters with this error:

Plan your calculations: Before diving into complex calculations, sketch out what you're trying to achieve and at what level of detail.
Understand your data structure: Knowing how your data is organized can help you anticipate and avoid aggregation conflicts.  Be able to articulate what each data row represents - that’s data granularity.
Use consistent aggregation: When creating calculated fields, use consistent aggregation methods across related measures and structure your naming conventions on aggregated calculated fields to be clear for other developers.
Test incrementally: Build complex calculations step by step, testing each component to ensure it behaves as expected.
By applying these methods and best practices, you'll not only resolve the "Cannot Mix Aggregate and Non-Aggregate" error but also develop a deeper understanding of how Tableau handles data at different levels of detail. This knowledge will prove invaluable as you create more sophisticated and insightful visualizations.

Mastering Aggregation in Tableau
As we've explored throughout this guide, understanding and effectively managing aggregation in Tableau is crucial for creating accurate, insightful visualizations. Let's recap the key points we've covered:

Key Takeaways:

The "Cannot Mix Aggregate and Non-Aggregate" error is Tableau's way of ensuring data integrity and preventing logical inconsistencies in your analysis.
Aggregation in Tableau involves summarizing data points into meaningful metrics like SUM, AVG, COUNT, and more.
The distinction between aggregated and non-aggregated data is fundamental to working effectively in Tableau.
Common solutions to aggregation errors include using LOD expressions, table calculations, and restructuring data sources.
As you continue to work with Tableau, remember that encountering aggregation challenges is a normal part of the learning process. Each time you resolve an aggregation issue, you're deepening your understanding of how Tableau handles data and improving your skills as a data analyst.

Remember, mastering aggregation in Tableau is an ongoing journey. Each project brings new challenges and opportunities to refine your skills. By understanding the principles we've discussed and continually practicing, you'll be well-equipped to handle even the most complex data visualization tasks.

At DataDrive, we're committed to helping you succeed in your data journey. Whether you're just starting out or looking to push the boundaries of what's possible with Tableau, we're here to support you. Don't hesitate to reach out if you have questions or need assistance with your Tableau projects.


Frequently Asked Questions (FAQs)
How to deal with "cannot mix aggregate and non-aggregate" error in Tableau? 

To resolve this error, ensure all fields in your calculation are at the same level of aggregation. Use aggregation functions (like SUM or AVG) for non-aggregated fields, or use Level of Detail (LOD) expressions to match aggregation levels.

What is aggregated and non-aggregated data in Tableau? 

Aggregated data in Tableau is summarized information (e.g., SUM of sales), while non-aggregated data represents individual, unsummarized records (e.g., individual sale transactions).

What is the difference between aggregated and non-aggregated data? 

Aggregated data combines multiple data points into a single value (like an average or total), while non-aggregated data maintains individual data points without summarization.

How do you group by and aggregate in Tableau? 

To group and aggregate in Tableau, drag dimension fields to the Rows or Columns shelf for grouping, then drag measure fields to the view and select an aggregation method (SUM, AVG, etc.) from the field's dropdown menu.

How do you avoid aggregation in Tableau? 

To avoid aggregation, right-click on a measure and select "Disaggregate" from the context menu. Alternatively, use ATTR() function or create a calculated field using raw data without aggregation functions.

How do I remove AGG in Tableau? 

To remove AGG (aggregation), right-click on the field in the view and select "Disaggregate." For calculated fields, rewrite the calculation without aggregation functions or use ATTR() to reference the raw values.

Does aggregation decrease granularity? 

Yes, aggregation decreases granularity by summarizing data points into higher-level information, reducing the level of detail in the data representation.

HOW TO RESOLVE THIS ERROR

### IMPORTANT 


Tableau
Search
 Tableau Help Tableau Desktop and Web Authoring Help ... Understanding Calculations Types of Calculations
Contents
Tableau Desktop and Web Authoring Help
Tableau Desktop and Web Authoring Release Notes
 Get Started
 Connect to and Prepare Data
 Build Charts and Analyze Data
Build Views and Explore Data with Tableau Agent
 Automatically Build Views with Ask Data
Add Web Images Dynamically to Worksheets
 Organize and Customize Fields in the Data Pane
 Build Data Views from Scratch
 Maps and Geographic Data Analysis
Add Viz Extensions to Your Worksheet
 Analyze Data
 Discover Insights Faster with Explain Data
 Explore and Inspect Data in a View
 Create Calculated Fields
Get Started with Calculations
Create a Simple Calculated Field
 Understanding Calculations
Types of Calculations
Choosing the Right Calculation Type
Tips for Learning How to Create Calculations
 Functions
 Table Calculations
 Level of Detail Expressions
Formatting Calculations
Best Practices for Creating Calculations
Tips for Working with Calculated Fields
Ad-Hoc Calculations
Spotlighting Using Calculations
 Spot Trends
 Forecast Data
 Predictive Modeling
 Einstein Discovery in Tableau
 Pass Expressions to Analytics Extensions
Integrate External Actions
Table Extensions
Calculate Percentages
 Create Dashboards
 Create Stories
 Create a Tableau Data Story (English Only)
 Format Worksheets and Workbooks
 Optimize Workbook Performance
 Save Work
 Publish Data Sources and Workbooks
Recycle Bin
 Use Tableau on the Web
 Install or Upgrade
Keyboard Shortcuts
Tableau Public FAQ
Copyright
Types of Calculations in Tableau
Applies to: Tableau Cloud, Tableau Desktop, Tableau Server
This article explains the types of calculations you can use in Tableau. You'll learn the difference between each calculation and how they are computed.

There are three main types of calculations you can use to create calculated fields in Tableau:

Basic expressions
Level of Detail (LOD) expressions
Table calculations
Basic expressions
Basic expressions allow you to transform values or members at the data source level of detail (a row-level calculation) or at the visualization level of detail (an aggregate calculation).

For example, consider the following sample table, which contains data on two fantasy authors and their books. Perhaps you want to create a column with only the author's last name and a column that displays how many books are in each series.

Book ID	Book Name	Series	Year Released	Author
1	The Lion, the Witch and the Wardrobe	The Chronicles of Narnia	1950	C.S. Lewis
2	Prince Caspian: The Return to Narnia	The Chronicles of Narnia	1951	C.S. Lewis
3	The Voyage of the Dawn Treader	The Chronicles of Narnia	1952	C.S. Lewis
4	The Silver Chair	The Chronicles of Narnia	1953	C.S. Lewis
5	The Horse and His Boy	The Chronicles of Narnia	1954	C.S. Lewis
6	The Magician's Nephew	The Chronicles of Narnia	1955	C.S. Lewis
7	The Last Battle	The Chronicles of Narnia	1956	C.S. Lewis
8	Daughter of the Forest	Sevenwaters	1999	Juliet Marillier
9	Son of the Shadows	Sevenwaters	2000	Juliet Marillier
10	Child of the Prophecy	Sevenwaters	2001	Juliet Marillier
11	Heir of Sevenwaters	Sevenwaters	2008	Juliet Marillier
12	Seer of Sevenwaters	Sevenwaters	2010	Juliet Marillier
13	Flame of Sevenwaters	Sevenwaters	2012	Juliet Marillier

Row-level calculations
To create a column that displays the author's last name for every row in the data source, you can use the following row-level calculation that splits on a space:

SPLIT([Author], '', 2 )

The result can be seen below. The new column, titled Author Last Name is shown on the far right. The colors demonstrate the level of detail the calculation is performed at. In this case, the calculation is performed at the row-level of the data source, so each row is colored separately.

Book ID	Book Name	Series	Year Released	Author	Author Last Name
1	The Lion, the Witch and the Wardrobe	The Chronicles of Narnia	1950	C.S. Lewis	Lewis
2	Prince Caspian: The Return to Narnia	The Chronicles of Narnia	1951	C.S. Lewis	Lewis
3	The Voyage of the Dawn Treader	The Chronicles of Narnia	1952	C.S. Lewis	Lewis
4	The Silver Chair	The Chronicles of Narnia	1953	C.S. Lewis	Lewis
5	The Horse and His Boy	The Chronicles of Narnia	1954	C.S. Lewis	Lewis
6	The Magician's Nephew	The Chronicles of Narnia	1955	C.S. Lewis	Lewis
7	The Last Battle	The Chronicles of Narnia	1956	C.S. Lewis	Lewis
8	Daughter of the Forest	Sevenwaters	1999	Juliet Marillier	Marillier
9	Son of the Shadows	Sevenwaters	2000	Juliet Marillier	Marillier
10	Child of the Prophecy	Sevenwaters	2001	Juliet Marillier	Marillier
11	Heir of Sevenwaters	Sevenwaters	2008	Juliet Marillier	Marillier
12	Seer of Sevenwaters	Sevenwaters	2010	Juliet Marillier	Marillier
13	Flame of Sevenwaters	Sevenwaters	2012	Juliet Marillier	Marillier

Aggregate calculations
To create a column that displays how many books are in each series, you can use the following aggregate calculation:

COUNT([Series])

The result can be seen below. The new column, titled Number of Books in Series - at Series level of detail shows how that calculation would be performed at the Series level of detail in the view. The colors help demonstrate the level of detail in which the calculation is being performed.

Series	Number of Books in Series - at Series level of detail
The Chronicles of Narnia	7
The Chronicles of Narnia
The Chronicles of Narnia
The Chronicles of Narnia
The Chronicles of Narnia
The Chronicles of Narnia
The Chronicles of Narnia
Sevenwaters	6
Sevenwaters
Sevenwaters
Sevenwaters
Sevenwaters
Sevenwaters

In Tableau, the data looks like this:

A table shows the aggregated book count in two series.

But if you drag in Book Id, (which is a more granular field), the calculation updates based on that new granularity since aggregate calculations are performed at the visualization level of detail.

A table shows the number of books per series, with a row for each book.

Level of Detail (LOD) expressions
Just like basic expressions , LOD expressions allow you to compute values at the data source level and the visualization level. However, LOD expressions give you even more control on the level of granularity you want to compute. They can be performed at a more granular level (INCLUDE), a less granular level (EXCLUDE), or an entirely independent level (FIXED).

For more information, see Create Level of Detail Expressions in Tableau(Link opens in a new window).

For example, consider the same sample table as above. If you wanted to compute when a book series was launched, you might use the following LOD expression:

{ FIXED [Series]:(MIN([Year Released]))}

The result can be seen below. The new column, titled Series Launched, displays the minimum year for each series. The colors help demonstrate the level of detail in which the calculation is being applied.

Book ID	Book Name	Series	Year Released	Author	Series Launched
1	The Lion, the Witch and the Wardrobe	The Chronicles of Narnia	1950	C.S. Lewis	1950
2	Prince Caspian: The Return to Narnia	The Chronicles of Narnia	1951	C.S. Lewis	1950
3	The Voyage of the Dawn Treader	The Chronicles of Narnia	1952	C.S. Lewis	1950
4	The Silver Chair	The Chronicles of Narnia	1953	C.S. Lewis	1950
5	The Horse and His Boy	The Chronicles of Narnia	1954	C.S. Lewis	1950
6	The Magician's Nephew	The Chronicles of Narnia	1955	C.S. Lewis	1950
7	The Last Battle	The Chronicles of Narnia	1956	C.S. Lewis	1950
8	Daughter of the Forest	Sevenwaters	1999	Juliet Marillier	1999
9	Son of the Shadows	Sevenwaters	2000	Juliet Marillier	1999
10	Child of the Prophecy	Sevenwaters	2001	Juliet Marillier	1999
11	Heir of Sevenwaters	Sevenwaters	2008	Juliet Marillier	1999
12	Seer of Sevenwaters	Sevenwaters	2010	Juliet Marillier	1999
13	Flame of Sevenwaters	Sevenwaters	2012	Juliet Marillier	1999

In Tableau, the calculation remains at the Series level of detail since it uses the FIXED function.

Viz showing the date 1950 for The Chronicles of Narnia and 1999 for Sevenwaters

If you add another field to the view (which adds more granularity) the values for the calculation are not affected, unlike an aggregate calculation.

Viz showing the date 1950 repeated for all Narnia books and 1999 for all Sevenwaters books

Table calculations
Table calculations allow you to transform values at the level of detail of the visualization only.

For more information, see Transform Values with Table Calculations(Link opens in a new window).

For example, consider the same sample table as above. If you wanted to compute the number of years since the author released their last book, you might use the following table calculation:

ATTR([Year Released]) - LOOKUP(ATTR([Year Released]), -1)

The result is shown below. The new column, titled Years Since Previous Book, displays the number of years between the book released in that row and the book released in the previous row (on the far right-side of the column) and demonstrates how the table calculation is being computed (on the left-side of the column).

The colors help demonstrate how the table calculation is being computed. In this case, the table calculation is being computed down each pane.

Note: Depending on the table calculation and how it is being computed across the table, the results may vary. For more information, see Transform Values with Table Calculations(Link opens in a new window).

Book ID	Book Name	Series	Year Released	Author	 Years Since Previous Book
1	The Lion, the Witch and the Wardrobe	The Chronicles of Narnia	1950	C.S. Lewis	NULL	 
2	Prince Caspian: The Return to Narnia	The Chronicles of Narnia	1951	C.S. Lewis	1951-	1950	1
3	The Voyage of the Dawn Treader	The Chronicles of Narnia	1952	C.S. Lewis	1952-	1951	1
4	The Silver Chair	The Chronicles of Narnia	1953	C.S. Lewis	1953-	1952	1
5	The Horse and His Boy	The Chronicles of Narnia	1954	C.S. Lewis	1954-	1953	1
6	The Magician's Nephew	The Chronicles of Narnia	1955	C.S. Lewis	1955-	1954	1
7	The Last Battle	The Chronicles of Narnia	1956	C.S. Lewis	1956-	1955	1
8	Daughter of the Forest	Sevenwaters	1999	Juliet Marillier	NULL	 
9	Son of the Shadows	Sevenwaters	2000	Juliet Marillier	2000-	1999	1
10	Child of the Prophecy	Sevenwaters	2001	Juliet Marillier	2001-	2000	1
11	Heir of Sevenwaters	Sevenwaters	2008	Juliet Marillier	2008-	2001	7
12	Seer of Sevenwaters	Sevenwaters	2010	Juliet Marillier	2010-	2008	2
13	Flame of Sevenwaters	Sevenwaters	2012	Juliet Marillier	2012-	2010	2

In Tableau, the data looks like this:

Viz showing the correct years since previous book for each book

However, if you change the visualization in a way that affects the layout, such as removing a dimension from the view, the calculation values change.

For example, in the image below, Author is removed from the viz. Since the table calculation is computed by pane, removing Author changes the granularity and layout of the viz (instead of two panes there is now only one). The table calculation therefore calculates the time between 1956 and 1999.

Viz showing incorrect years since previous book for the Sevenwaters books


Continue to Choosing the Right Calculation Type
See Also
Understanding Calculations in Tableau(Link opens in a new window)

Tips for Learning How to Create Calculations(Link opens in a new window)


 Back to top
Did this article solve your issue?
Let us know so we can improve!
Yes 
No 
In this article
Basic expressions
Level of Detail (LOD) expressions
Table calculations
Continue to Choosing the Right Calculation Type
See Also
LegalTerms of ServicePrivacy InformationResponsible DisclosureTrustContactYour Privacy Choices
© Copyright 2025 Salesforce, Inc. All rights reserved. Various trademarks held by their respective owners. Salesforce, Inc. Salesforce Tower, 415 Mission Street, 3rd Floor, San Francisco, CA 94105, United States.


Aggregations in Tableau
While performing analytics, Tableau by default will automatically aggregate or disaggregate your fields based on how you position them in your view. We have all seen the “Sales” field change to SUM(Sales) when we put it on the row shelf for example. That is a type of aggregation. Aggregations allow summarisation of your data which increases the value of the information by preparing your data to be viewed in visualisations. Where Tableau excels in.

Measures and dimensions can both be aggregated, however it is most commonly measures that are aggregated. Measures are automatically aggregated when put it the view. To change the aggregation of a field, one of the ways is to right-click a pill on the view and change the aggregation from there. As default, the aggregation is to SUM. However, different type of aggregations for measures exist as follows:


Aggregations also exist for dimensions, however they are more limited while compared to measures:


For more information on aggregations, see the help documentation on Data Aggregation in Tableau.

Aggregations in Calculations
It is possible to change the aggregation of your fields from the data pane or from the shelves where your fields exist in. However, aggregations can also be configured as calculated fields as well. Using calculated fields allows the user to create their own data in a way that is not supplied by the data source itself. Therefore, it opens up the possibility to change the means of aggregation when combining fields.

For example lets say I have Profit and Sales in my data source and I want to create a profit to sales ratio. I will need to create a calculated field for this instance. However, it is very important to define what exactly I want to see from this calculation. And it depends on using aggregated or non-aggregated fields in my calculation.

In the profit to sales ratio example, the calculation can be written in two ways that will result in completely different results. The first one is with a SUM wrapped around each field as follows:


Profit Ratio Calculation with Aggregation
Or without the aggregation as follows:


Profit Ratio Calculation without Aggregation
Understanding the Difference
To understand the difference, it is important to understand how Tableau interprets these two calculations. In the first example, Tableau is summing all profit and sales values from each row, and dividing them together. This results in a pre-aggregated field. Therefore, when this newly created field is put on the view, the pill will have an AGG() wrapped around the field. Depending on your dimensions on the view, the calculation will change to only include those members from that dimension. In the below example this calculation is used against the sub-category field:


It can be observed that the numbers seem correct. They all stay in the ratio range. However if I use the same example with the calculation without aggregation, I get different results as follows:


The result is definitely not right. If you notice, instead of AGG, I get the default SUM aggregation to my non-aggregated calculation. That is because Tableau has automatically aggregated that field once put on the view. It is in Tableau’s nature, it wants to aggregate.

What the non-aggregated field does is that Tableau calculates the profit to sales ratio for each row and stores that value. And at the end in this case, it is summing up all the calculated values together. If we make this profit ratio field a dimension instead of a measure, it makes more sense how it is done:


Last Month:

IF DATEDIFF("month",DATETRUNC( "month",     attr(      [Original Start Date])),DATETRUNC("month", TODAY() ))

=1

THEN [Measure_PAR] END













Level of Detail Expressions and Aggregation
Applies to: Tableau Cloud, Tableau Desktop, Tableau Public, Tableau Server
The level of detail of the view determines the number of marks in your view. When you add a level of detail expression to the view, Tableau must reconcile two levels of detail—the one in the view, and the one in your expression.

The behavior of a level of detail expression in the view varies depending on whether the expression's level of detail is coarser, finer, or the same as the level of detail in the view. What do we mean by “coarser” or “finer” in this case?

Level of Detail Expression is Coarser Than View Level of Detail
An expression has a coarser level of detail than the view when it references a subset of the dimensions in the view. For example, for a view that contained the dimensions [Category] and [Segment], you could create a level of detail expression that uses only one of these dimensions:

{FIXED [Segment] : SUM([Sales])}

In this case, the expression has a coarser level of detail than the view. It bases its values on one dimension ([Segment]), whereas the view is basing its view on two dimensions ([Segment] and [Category]).

The result is that using the level of detail expression in the view causes certain values to be replicated—that is, to appear multiple times.

A table that displays sales by customer segment and product category, with arrows showing the relationship between LOD expression returns, dimensions in the viz sheet, and their replication as results per segment sales.

Replicated values are useful for comparing specific values against average values within a category. For example the following calculation subtracts average sales for a customer from the average sales overall:

[Sales] - {FIXED [Customer Name] : AVG([Sales])}

When values are being replicated, changing the aggregation for the relevant field in the view (for example, from AVG to SUM) will not change the result of the aggregation.

Level of Detail Expression is Finer Than View Level of Detail
An expression has a finer level of detail than the view when it references a superset of the dimensions in the view. When you use such an expression in the view, Tableau will aggregate results up to the view level. For example, the following level of detail expression references two dimensions:

{FIXED [Segment], [Category] : SUM([Sales])}

When this expression is used in a view that has only [Segment] as its level of detail, the values must be aggregated. Here’s what you would see if you dragged that expression to a shelf:

AVG([{FIXED [Segment]], [Category]] : SUM([Sales]])}])

An aggregation—in this case, average—is automatically assigned by Tableau. You can change the aggregation as needed.

Adding a Level of Detail Expression to the View
Whether a level of detail expression is aggregated or replicated in the view is determined by the expression type (FIXED, INCLUDE, or EXCLUDE) and whether the expression’s granularity is coarser or finer than the view’s.

INCLUDE level of detail expressions will have either the same level of detail as the view or a finer level of detail than the view. Therefore, values will never be replicated.

FIXED level of detail expressions can have a finer level of detail than the view, a coarser level of detail, or the same level of detail. The need to aggregate the results of a FIXED level of detail depends on what dimensions are in the view.

EXCLUDE level of detail expressions always cause replicated values to appear in the view. When calculations including EXCLUDE level of detail expressions are placed on a shelf, Tableau defaults to the ATTR aggregation (as opposed to SUM or AVG) to indicate that the expression is not actually being aggregated and that changing the aggregation will have no effect on the view.

Level of detail expressions are always automatically wrapped in an aggregate when they are added to a shelf in the view unless they’re used as dimensions. So if you double-click on a shelf and type

{FIXED[Segment], [Category] : SUM([Sales])}

and then press Enter to commit the expression, what you now see on the shelf is

SUM({FIXED[Segment], [Category] : SUM([Sales])})

But if you double-click into the shelf to edit the expression, what you see in edit mode is the original expression.

If you wrap a level of detail expression in an aggregation when you create it, Tableau will use the aggregation you specified rather than assigning one when any calculation including that expression is placed on a shelf. When no aggregation is needed (because the expression’s level of detail is coarser than the view’s), the aggregation you specified is still shown when the expression is on a shelf, but it is ignored.





Analyze the following guide for building a dynamic, multi-level drill-down visualization in Tableau. Deconstruct the methodology into its core logical components: state management, conditional rendering of data, and dynamic view composition.
The primary objective is to create an interactive crosstab where a user click on a dimension member triggers an expansion to show its children in the next level of the hierarchy. The view must dynamically add and remove columns and only show data relevant to the user's selection path.
Here is the logic, broken down into a machine-readable format:
1. Core Concept: State Management via Sets
The state of the user's interaction (i.e., the current drill-down path) is managed through a series of Sets.
Initialization: For each level of the hierarchy H(n) that a user can drill from (e.g., Category, Sub-Category, Product Type), create a corresponding Set(n).
State Transition: The state is modified by Dashboard Set Actions.
Trigger: A user onClick event on a mark within a specific worksheet.
Action: The action ADDs the selected dimension value to its corresponding Set(n). This signifies a "drill-down" intent.
Reversal: The action is configured so onClear or a subsequent onClick event REMOVEs the value from the Set(n). This signifies a "roll-up" intent.
State Inspection: The state of the system at any time is determined by querying the contents and count of members within these Sets. We use helper calculated fields for this:
[Count of Set(n)]: A distinct count of the Set's IN/OUT filter values. A count of 2 definitively means a partial selection exists. A count of 1 means either "all" or "none" are selected.
[Set(n) Selection Check]: A direct count of members in the set, used to disambiguate the [Count of Set(n)] = 1 scenario.
2. Core Concept: Conditional Data Rendering via Calculated Fields
Raw data fields are not used directly. Instead, "dynamic" calculated fields are created. Their output is conditional on the state of the Sets.
Dynamic Dimensions: To display the next level H(n+1) of the hierarchy, create a calculated field [Dynamic Dimension H(n+1)].
Logic: IF [Dimension H(n)] IN Set(n) THEN [Dimension H(n+1)] ELSE NULL END.
Function: This populates the child members of the selected parent, effectively linking the hierarchy levels. The Set(n+1) is then created from this dynamic field, not the original dimension.
Dynamic Measures: To ensure measure values only appear on rows relevant to the full selection path, create calculated fields like [Dynamic Measure X].
Logic: IF (condition for Set(1) is met) AND (condition for Set(2) is met) AND ... THEN [Original Measure X] ELSE NULL END.
Function: This prevents measures from appearing on unselected or higher-level rows after a drill-down has occurred.
3. Core Concept: Dynamic View Composition via Sheet Swapping
To make entire columns appear or disappear (not just their data), multiple worksheets are composed into a single view using a "sheet swapping" technique.
View Templates: Create a separate worksheet for each possible drill-down depth.
Worksheet 1: Displays hierarchy level H(1) only.
Worksheet 2: Displays H(1) and H(2).
Worksheet N: Displays H(1) through H(N).
View Controller/Router: A single calculated field, [Sheet Swap Filter], acts as the master controller.
Logic: This is a multi-step IF/ELSEIF statement that evaluates the state of all Set(n) controllers. Based on the combination of set states, it returns a unique string identifier for the view that should be active (e.g., "CategoryView", "SubCategoryView").
Example Logic Snippet: IF [Count of Set(1)] = 1 THEN "CategoryView" ELSEIF [Count of Set(1)] = 2 AND [Count of Set(2)] = 1 THEN "SubCategoryView" ... END
Assembly:
Place all worksheets into a single Container object on the dashboard.
Apply the [Sheet Swap Filter] as a filter to each worksheet, setting each one to display only when its unique identifier is returned (e.g., filter Worksheet 1 to "CategoryView").
Hide all titles and ensure the fit is set to "Entire View". This creates a seamless swap where only one worksheet is visible at a time.
Summary of the Algorithm:
Model State: Define the drill-down hierarchy and create a corresponding Set for each parent level.
Model Data: Abstract the raw dimensions and measures into dynamic calculated fields whose outputs are conditional on the state of the Sets.
Model Views: Create discrete worksheet templates, one for each required view state (drill-down depth).
Implement Controller: Write a master calculated field (Sheet Swap Filter) that maps the system's current state (derived from the Sets) to a specific view template.
Wire Actions: On a dashboard, composite the worksheets in a container and use Set Actions to link user onClick events to state changes in the Sets, which in turn triggers the controller to swap the visible worksheet. The system is event-driven, with the user's click initiating a state change that propagates through the calculated fields and view controller.






