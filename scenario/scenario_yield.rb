#! ruby -E utf-8

define :func1 do
    _EVAL_ "pp 'EVAL func1'"
    pp "pp func1"
    _YIELD_
end

define :func2 do
    _EVAL_ "pp 'EVAL func2'"
    pp "pp func2"
    func1 do
      _EVAL_ "pp 'EVAL func1 YIELD in func2'"
      pp "pp  func1 YIELD in func2"
      _YIELD_
   
  end
end

define :func3 do
    _EVAL_ "pp 'EVAL func3'"
    pp "pp func3"
    func2 do
      _EVAL_ "pp 'EVAL func2 YIELD in func3'"
      pp "pp  func2 YIELD in func3"
      _YIELD_
   
  end
end

_EVAL_ "pp 'TEST1'"

func1 do
  _EVAL_ "pp 'EVAL func1 YIELD'"
  pp "pp  func1 YIELD"
  _YIELD_
end

_EVAL_ "pp 'TEST2'"

#function�����s��A�u���b�N���̃R�}���h�����s����
#TODO�Fabout�ł͂Ȃ��Afunc2�̈����ő��M����w��ł��Ȃ����̂�
func2 do
  _EVAL_ "pp 'EVAL func2 YIELD'"
  pp "pp func2 YIELD"
end

_EVAL_ "pp 'TEST3'"

func3 do
  _EVAL_ "pp 'EVAL func3 YIELD'"
  pp "pp func3 YIELD"
end