#Requires AutoHotkey v2.0

class ReactiveRuntime {
    static Current := 0
    static BatchDepth := 0
    static Queue := []
    static Queued := Map()
    static Flushing := false

    static Track(node) {
        if IsObject(this.Current)
            this.Current._RegisterDependency(node)
    }

    static Batch(callback) {
        this.BatchDepth += 1
        try callback.Call()
        finally {
            this.BatchDepth -= 1
            if this.BatchDepth = 0
                this.Flush()
        }
    }

    static Enqueue(computed) {
        if this.Queued.Has(computed)
            return

        this.Queued[computed] := true
        this.Queue.Push(computed)
        if this.BatchDepth = 0 && !this.Flushing
            this.Flush()
    }

    static Flush() {
        if this.Flushing
            return

        this.Flushing := true
        try {
            while this.Queue.Length {
                computed := this.Queue.RemoveAt(1)
                this.Queued.Delete(computed)
                if computed.Dirty
                    computed._Recompute()
            }
        } finally {
            this.Flushing := false
        }
    }
}

class ReactiveSubscription {
    __New(owner, callback) {
        this.Owner := owner
        this.Callback := callback
        this.Active := true
    }

    Dispose() {
        if !this.Active
            return

        this.Active := false
        this.Owner._RemoveSubscription(this)
    }
}

class ReactiveNode {
    __New() {
        this.Dependents := Map()
        this.Subscribers := Map()
    }

    Subscribe(callback, emitCurrent := false) {
        currentValue := 0
        if emitCurrent
            currentValue := this.Value

        sub := ReactiveSubscription(this, callback)
        this.Subscribers[sub] := callback
        if emitCurrent
            callback.Call(currentValue)
        return sub
    }

    _RemoveSubscription(sub) {
        if this.Subscribers.Has(sub)
            this.Subscribers.Delete(sub)
    }

    _Notify(value, oldValue := unset) {
        snapshot := []
        for sub, callback in this.Subscribers
            snapshot.Push([sub, callback])

        for pair in snapshot {
            if !pair[1].Active
                continue
            if IsSet(oldValue)
                pair[2].Call(value, oldValue)
            else
                pair[2].Call(value)
        }
    }

    _AddDependent(computed) {
        this.Dependents[computed] := true
    }

    _RemoveDependent(computed) {
        if this.Dependents.Has(computed)
            this.Dependents.Delete(computed)
    }

    _InvalidateDependents() {
        snapshot := []
        for dependent in this.Dependents
            snapshot.Push(dependent)
        for dependent in snapshot
            dependent._InvalidateFrom(this)
    }
}

class Signal extends ReactiveNode {
    __New(value) {
        super.__New()
        this._Value := value
    }

    Value {
        get {
            ReactiveRuntime.Track(this)
            return this._Value
        }
        set => this.Set(value)
    }

    Set(value) {
        oldValue := this._Value
        if this._Same(oldValue, value)
            return false

        this._Value := value
        this._InvalidateDependents()
        this._Notify(value, oldValue)
        return true
    }

    _Same(left, right) {
        if IsObject(left) || IsObject(right)
            return IsObject(left) && IsObject(right) && ObjPtr(left) = ObjPtr(right)
        return left == right
    }
}

class Computed extends ReactiveNode {
    __New(evaluator) {
        super.__New()
        this.Evaluator := evaluator
        this.Dependencies := Map()
        this.NewDependencies := 0
        this.Dirty := true
        this.Evaluating := false
        this.HasValue := false
        this._Value := 0
    }

    Value {
        get {
            ReactiveRuntime.Track(this)
            if this.Dirty
                this._Recompute()
            return this._Value
        }
    }

    _RegisterDependency(node) {
        if !IsObject(this.NewDependencies)
            throw Error("Dependency registered outside computation.")
        if this.NewDependencies.Has(node)
            return

        this.NewDependencies[node] := true
        node._AddDependent(this)
    }

    _InvalidateFrom(source) {
        if this.Dirty
            return

        this.Dirty := true
        this._InvalidateDependents()
        if this.Subscribers.Count > 0
            ReactiveRuntime.Enqueue(this)
    }

    _Recompute() {
        if !this.Dirty
            return this._Value
        if this.Evaluating
            throw Error("Reactive dependency cycle detected.")

        this.Evaluating := true
        previousCurrent := ReactiveRuntime.Current
        oldDependencies := this.Dependencies
        this.NewDependencies := Map()
        ReactiveRuntime.Current := this

        try nextValue := this.Evaluator.Call()
        finally {
            ReactiveRuntime.Current := previousCurrent
            this.Evaluating := false
        }

        for dependency in oldDependencies {
            if !this.NewDependencies.Has(dependency)
                dependency._RemoveDependent(this)
        }

        this.Dependencies := this.NewDependencies
        this.NewDependencies := 0
        oldValue := this._Value
        hadValue := this.HasValue
        changed := !hadValue || !this._Same(oldValue, nextValue)
        this._Value := nextValue
        this.HasValue := true
        this.Dirty := false

        if changed && this.Subscribers.Count > 0 {
            if hadValue
                this._Notify(nextValue, oldValue)
            else
                this._Notify(nextValue)
        }
        return nextValue
    }

    _Same(left, right) {
        if IsObject(left) || IsObject(right)
            return IsObject(left) && IsObject(right) && ObjPtr(left) = ObjPtr(right)
        return left == right
    }
}

Print(text) {
    FileAppend(text "`n", "*")
}

price := Signal(100)
quantity := Signal(2)
discount := Signal(0.10)
subtotal := Computed(() => price.Value * quantity.Value)
total := Computed(() => Round(subtotal.Value * (1 - discount.Value), 2))
notifications := []
totalSub := total.Subscribe((value, oldValue := unset) => notifications.Push(value), true)

ReactiveRuntime.Batch(() => (price.Value := 120, quantity.Value := 3))
discount.Value := 0.20

Print("initial=" notifications[1])
Print("after_batch=" notifications[2])
Print("after_discount=" notifications[3])
Print("notification_count=" notifications.Length)
Print("total=" total.Value)

cycleA := 0
cycleB := 0
cycleA := Computed(() => cycleB.Value + 1)
cycleB := Computed(() => cycleA.Value + 1)
cycleDetected := false
try cycleA.Value
catch Error as err
    cycleDetected := InStr(err.Message, "cycle") > 0
Print("cycle_detected=" cycleDetected)
totalSub.Dispose()

; Expected:
; initial=180
; after_batch=324
; after_discount=288
; notification_count=3
; total=288
; cycle_detected=1
