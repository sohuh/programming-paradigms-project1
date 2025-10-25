# Sohaib Rehmans Racket Calculator
This is for my Programming Paradigms project

Things to have prior to using the code:
I suggest having the latest installation of Racket on your PC prior to running it, this was coded in Racket 8.18
you can find this here: https://racket-lang.org/download/

Files Explained:
Within this project file you have four files, the devlog.md which has all my thoughts while I was working on the project,
the Paradigms Project File.rkt which is the main racket file with the calculator, the README file which has general instructions, 
and the test_cases.txt file which can be used for batch testing.

Running the Code:
To run the code in simple input mode, type " racket "Paradigms Project File.rkt" " into the cli and it will begin to prompt you on what inputs you want.
This calculator runs on prefix notation so all input should be formatted as such:
operator integer1 integer2
Operators include:
+, * , /
integer1 and integer2 can be any number.
You may notice that there is no subtraction, this is because to subtract you can just add a negative number which can be done like this:

\+ 20 -10 = 10 which is the same as 20 - 10 = 10

Furthermore, you can reference previous values this is done by doing $(number of value) this number is established after the calculation for example

\+ 2 5 
1: 7.0

\+ $1 6
2: 13.0

Meaning you would refer to the number prior to the result for future references.

Exiting the Code:
To exit simply type " quit " .

Running the Code with a batch file:
To run the code in batch file mode follow this command: 
racket "Paradigms Project File.rkt" -b < (your test files name).txt
After the calculator is finished running the code it will print out only the OUTPUT of the calculations along with their numbers, if the output is invalid 
it will return "Error: Invalid Expression"

NOTES FOR THE TA:
All numbers are returned as floats

I added extra comments within the code for more readability and more precise error handling / tracing parts so if you have any questions regarding it let me know!
Also this was all coded in VS code as my natural IDE, so it should run best within said environment.