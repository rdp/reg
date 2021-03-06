module Instrument; end
class<<Instrument
  def unique_num
    @count||=-1
    @count+=1
  end

  def output
    @output ||= $stdout
  end
  
  attr_writer :output
  
  def indentlevel
    @indentlevel ||= 0
  end

  attr_writer :indentlevel

  def puts str
    output.puts " "*indentlevel+str
  end
  
  def methodlog args,pre,method,post,exprs
          puts [pre,method,"(",            
            exprs.map{|expr,name| name.to_s+"=>"+expr.inspect },
          ")",post ].to_s
  end
  
  def parseargs(klass,method,*data)
    klass=klass.to_s
    klass="::"+klass unless /^::/===klass
    data.last.is_a? Hash and pretty_exprs= data.pop and pretty_exprs.each{|expr,name| pretty_exprs[expr]=name.to_s }
    exprs=data.map{|datum|
      case datum
        when String,Symbol; datum.to_s
        when Integer,Range; "args[#{datum}]"
        else datum.to_str
      end
    }
    id=unique_num
    
    return klass,method,exprs,pretty_exprs||{},id
  end

  def to_code(exprs)
    if exprs.is_a? Hash
      exprs.map{|expr,name|
        "'#{name}'=>(#{expr}).inspect"
      }
    else
      exprs.map{|expr|
        "'#{expr}'=>(#{expr}).inspect"
      }
    end
  end

  def on_entry_to(*data)
    klass,method,exprs,pretty_exprs,id=parseargs *data
    exprs=to_code(exprs)+to_code(pretty_exprs)
    eval <<-"end_rewrite"
      class #{klass}
        alias no_entry_instrument#{id}_#{method} #{method}
        def #{method}(*args,&block)
          Instrument.methodlog(args,"<",#{method.inspect},"",#{'{}' if exprs.empty?}#{exprs.join(',')})
          Instrument.indentlevel+=1
          no_entry_instrument#{id}_#{method}(*args,&block)
        ensure
          Instrument.indentlevel-=1
        end
      end
    end_rewrite
  end

  def on_exit_from(*data)
    klass,method,exprs,pretty_exprs,id=parseargs *data
    exprs=to_code(exprs)+to_code(pretty_exprs)
    eval <<-"end_rewrite"
      class #{klass}
        alias no_exit_instrument#{id}_#{method} #{method}
        def #{method}(*args,&block)
          result=no_exit_instrument#{id}_#{method}(*args,&block)
        ensure
          Instrument.methodlog(args,">",#{method.inspect},"=\#{result.inspect}",#{'{}' if exprs.empty?}#{exprs.join(',')})
        end
      end
    end_rewrite
  end

end
