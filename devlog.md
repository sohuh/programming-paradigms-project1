October 15th
The problem of the project seems fairly easy, I believe we are taking in input in prefix notation as stated within the assignment so I think I need to start with 
figuring out how I will take in, input and have the operations be done to it. 
I think this should be done in the following way:
    * First we need to parse the input we know that all inputs will be in the following format (operator) (integer 1) (integer 2)
    * So after we parse the input we identify what operation must be done and then apply it to the two integers and store this value
    * with the new stored value print it out and retain that racket value
    * have it recursively take in, input to keep the calculator going unless a "quit" keyword is used

October 17th
I started working on the proper implementation today and added the following:
    * I added the two usage types which were mentioned which was a batch mode and an interactive mode 
    * I added a tokenizer which splits input strings into tokens and then finds the operator and ignores parantheses
    Furthermore, the tokenizer treats negatives differently, it treats for example "-3" as the following "-" is a unary operator and the three is a seperate integer
    * I added the prefix evaluator which takes in eval tokens and then prarses an expression from the front ofa token list and returns two values, the numeric result and the remaining tokens, if there is an error it returns an exception 
    Its not done yet, but whenever I get the chance I should be able to finish it, it seems like I am almost done overall very productive day 8/10

October 19th
I have been completely slammed with work for other classes, along with the homework for this class so I have not had much time for this class but I do think I know whats left to do
I think I need to have it take in input and then run it through so I will do that next!

October 23rd
So I lucked out, I have been coding in racket this whole time and luckily that was right beccause some people were coding in haskell, hopefully I can finish my code and test it tomorrow so I can be done with it.

October 24th (Morning)
Finished writing the calculator program itself and ran it normally and it was working just fine on evertyhing, need to go out for a bit so will test with batch and write the readme for the final touches later today.
