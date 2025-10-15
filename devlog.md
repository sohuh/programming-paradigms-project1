October 15th
The problem of the project seems fairly easy, I believe we are taking in input in prefix notation as stated within the assignment so I think I need to start with 
figuring out how I will take in, input and have the operations be done to it. 
I think this should be done in the following way:
    * First we need to parse the input we know that all inputs will be in the following format (operator) (integer 1) (integer 2)
    * So after we parse the input we identify what operation must be done and then apply it to the two integers and store this value
    * with the new stored value print it out and retain that racket value
    * have it recursively take in, input to keep the calculator going unless a "quit" keyword is used
