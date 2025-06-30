module Topia
  # Base pipeline interface without generics to avoid union issues
  abstract class BasePipeline
    abstract def value
    abstract def transform(plugin : Plugin) : BasePipeline
    abstract def type_name : String
  end

  # Type-safe pipeline implementation
  class Pipe(T) < BasePipeline
    getter value : T

    def initialize(@value : T)
    end

    def transform(plugin : Plugin) : BasePipeline
      result = plugin.run(@value)
      case result
      when Array(InputFile)
        Pipe(Array(InputFile)).new(result)
      when String
        Pipe(String).new(result)
      when Bool
        Pipe(Bool).new(result)
      else
        # For unknown types, preserve as untyped
        Pipe(typeof(result)).new(result)
      end
    end

    def pipe(plugin : Plugin) : BasePipeline
      transform(plugin)
    end

    def type
      T
    end

    def type_name : String
      T.to_s
    end
  end

  # Pipeline builder for composable transformations
  class PipelineBuilder
    @pipeline : BasePipeline?

    def initialize
      @pipeline = nil
    end

    def start(value : T) : PipelineBuilder forall T
      @pipeline = Pipe(T).new(value)
      self
    end

    def pipe(plugin : Plugin) : PipelineBuilder
      if current = @pipeline
        @pipeline = current.transform(plugin)
      end
      self
    end

    def build : BasePipeline?
      @pipeline
    end

    def value
      @pipeline.try(&.value)
    end
  end
end
