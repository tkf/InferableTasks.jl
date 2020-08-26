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

# Use the world age that would be used from
# `Core.Compiler.return_type(f, t)`.  This is different from what
# `Base.get_world_counter` returns.  A big thanks to Chris Foster!:
# https://discourse.julialang.org/t/can-we-have-inferable-fetch-task/45541/2
_get_world_counter() = ccall(:jl_get_tls_world_age, UInt, ())

# I'm hoping this would make sure that the caller of `@ispawn` would
# be invalidated if the function `$f` has to be invalidated.  If the
# caller is invalidated, it'll get a new world age.  This in turn,
# invalidates `$f` called in the task because it is now called from a
# new world age (via `invoke_in_world`).
# --- https://discourse.julialang.org/t/can-we-have-inferable-fetch-task/45541/4
const __NEVER = Ref(false)

function inferable(spawn_macro, ex)
    @gensym f T world
    quote
        local $f, $T, $world
        $Base.@noinline $f() = $ex
        if $__NEVER[]
            $f()
        end
        $T = $Core.Compiler.return_type($f, $Tuple{})
        $world = $_get_world_counter()
        $InferableTask{$T}($(spawn_macro(:($Base.invoke_in_world($world, $f)))))
    end
end

end
