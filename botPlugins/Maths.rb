# Ng Guoyou
# Maths.rb
# This plugin evaluates basic mathematical expressions without the use of eval,
# through the judicious usage of shunting-yard algorithm and reverse polish notation.

class Maths < BotPlugin
  def initialize
    # Authorisations
    @reqAuthLevel = 0

    # Strings
    @noAuthMessage = "You are not authorised for this."

    # Required plugin stuff
    name = self.class.name
    @hook = ["math", "maths"]
    processEvery = false
    @help = "Usage: #{@hook} <expression>\nFunction: Evaluates basic mathematical expressions. Accepts +, -, /, *, ^, **, >, <, >=, <=, == and % as operators."
    super(name, @hook, processEvery, @help)
  end

  def main(data)
    @givenLevel = data["authLevel"]
    rs = reversePolishNotation(shuntInput(formatInput(stripWordsFromStart(data["message"], 1))))
    rs = @help if rs == nil

    return authCheck(@reqAuthLevel) ? sayf(rs) : sayf(@noAuthMessage)
  rescue => e
    handleError(e)
    return sayf(e)
  end

  def shuntInput(s)
    # According to http://en.wikipedia.org/wiki/Shunting-yard_algorithm#The_algorithm_in_detail
    stack = []
    outputQueue = []

    s.each { |token|
      if isNumber?(token)
        outputQueue.push(token)
      elsif isOperator?(token)
        while isOperator?(stack.last) &&
          ((getPrecedence(token)[:a] == 'left' && (getPrecedence(token)[:p] <= getPrecedence(stack.last)[:p])) ||
           (getPrecedence(token)[:a] == 'right' && (getPrecedence(token)[:p] < getPrecedence(stack.last)[:p])))
          outputQueue.push(stack.pop)
        end

        stack.push(token)
      elsif token == '('
        stack.push(token)
      elsif token == ')'
        while stack.last != '('
          outputQueue.push(stack.pop)
          raise "Syntax Error: Mismatched parentheses" if stack.size == 0
        end

        stack.pop if stack.last == '('
      end
    }

    while stack.size > 0
      if stack.last == '('
        raise "Syntax Error: Mismatched parentheses"
      else
        outputQueue.push(stack.pop)
      end
    end

    puts "Shunted: #{outputQueue.join(' ')}"
    return outputQueue
  end

  def reversePolishNotation(expr)
    # According to http://en.wikipedia.org/wiki/Reverse_polish_notation#Postfix_algorithm
    stack = []

    while expr.size > 0
      if isNumber?(expr.first)
        stack.push(expr.shift.to_f)
      else
        # If fewer values than function/operator's arguments
        raise 'Syntax Error: Insufficient values' if stack.size < 2

        rightVal = stack.pop
        leftVal = stack.pop
        stack.push(leftVal.send(expr.first, rightVal))
        expr.shift
      end

        puts "RPN: Stack: #{stack.join(" ")} Expression: #{expr.join(" ")}"
    end

    return stack[0]
  end

  def getPrecedence(c)
    case c
    when '^' then
      return {p: 4, a: 'right'}
    when '**' then
      return {p: 4, a: 'right'}
    when '*' then
      return {p: 3, a: 'left'}
    when '/' then
      return {p: 3, a: 'left'}
    when '%' then
      return {p: 3, a: 'left'}
    when '+' then
      return {p: 2, a: 'left'}
    when '-' then
      return {p: 2, a: 'left'}
    when '>' then
      return {p: 1, a: 'left'}
    when '<' then
      return {p: 1, a: 'left'}
    when '>=' then
      return {p: 1, a: 'left'}
    when '<=' then
      return {p: 1, a: 'left'}
    when '==' then
      return {p: 1, a: 'left'}
    else
      return {p: 0, a: 'left'}
    end
  end

  def isOperator?(c)
    return /(\^|\*\*|\*|\/|\+|\-|\%|>|<|<=|>=|==)/ === c ? true : false
  end

  def isNumber?(s)
    return /\d+(.\d+)?/ === s ? true : false
  end

  def formatInput(s)
    # Can be improved
    s.gsub!(/ /, '')
    s.gsub!('*', ' * ')
    s.gsub!('^', ' ** ')
    s.gsub!(' * * ', ' ** ')
    s.gsub!('+', ' + ')
    s.gsub!('-', ' - ')
    s.gsub!('/', ' / ')
    s.gsub!('%', ' % ')
    s.gsub!('(', ' ( ')
    s.gsub!(')', ' ) ')
    s.gsub!('>', ' > ')
    s.gsub!('<', ' < ')
    s.gsub!(' > =', ' >= ')
    s.gsub!(' < =', ' <= ')
    s.gsub!('==', ' == ')
    s = s.split(' ')

    return s
  end
end