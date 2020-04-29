import sys
print(sys.version)
print(sys.prefix)

# Python program to find the factorial of a number
num = 65
factorial = 1
print("Find the factorial of ", num)
for i in range(1, num + 1):
    factorial = factorial*i
print("The factorial of ", num, " is ", factorial)