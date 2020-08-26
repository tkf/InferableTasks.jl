module InferableTasks

export @iasync, @ispawn

struct InferableTask{T}
    task::Task
end

Base.fetch(t::InferableTask{T}) where {T} = fetch(t.task)::T
Base.wait(t::InferableTask) = wait(t.task)

macro ispawn(ex)
    inferable(ex) do ex
        :($Threads.@spawn $ex)
    end |> esc
end

macro iasync(ex)
    inferable(ex) do ex
        :($Base.@async $ex)
    end |> esc
end

function inferable(spawn_macro, ex)
    @gensym f T world
    quote
        local $f, $T, $world
        $f() = $ex
        $T = $Core.Compiler.return_type($f, $Tuple{})
        $world = $Base.get_world_counter()
        $InferableTask{$T}($(spawn_macro(:($Base.invoke_in_world($world, $f)))))
    end
end

end
