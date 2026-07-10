#Requires AutoHotkey v2.0

class Query {
    __New(source) {
        this.Source := source
    }

    static From(source) {
        return Query(source)
    }

    static Range(start := 1, step := 1, stop := unset) {
        if IsSet(stop)
            return Query(RangeSource(start, step, stop))
        return Query(RangeSource(start, step))
    }

    Map(selector) {
        return Query(MapSource(this, selector))
    }

    Filter(predicate) {
        return Query(FilterSource(this, predicate))
    }

    Take(count) {
        return Query(TakeSource(this, count))
    }

    Skip(count) {
        return Query(SkipSource(this, count))
    }

    Scan(seed, accumulator) {
        return Query(ScanSource(this, seed, accumulator))
    }

    Distinct(keySelector := unset) {
        if IsSet(keySelector)
            return Query(DistinctSource(this, keySelector))
        return Query(DistinctSource(this))
    }

    ToArray() {
        values := []
        for value in this
            values.Push(value)
        return values
    }

    __Enum(numVars) {
        if numVars != 1
            throw ValueError("Query supports one loop variable.", -1, numVars)
        return this.Source.__Enum(1)
    }
}

class RangeSource {
    __New(start, step, stop := unset) {
        if step = 0
            throw ValueError("Range step cannot be zero.")

        this.Start := start
        this.Step := step
        this.Bounded := IsSet(stop)
        this.Stop := this.Bounded ? stop : 0
        this.Produced := 0
    }

    __Enum(numVars) {
        if numVars != 1
            throw ValueError("RangeSource supports one loop variable.", -1, numVars)
        return RangeIterator(this)
    }
}

class RangeIterator {
    __New(source) {
        this.Source := source
        this.NextValue := source.Start
    }

    Call(&value) {
        source := this.Source
        if source.Bounded {
            if source.Step > 0 && this.NextValue > source.Stop
                return false
            if source.Step < 0 && this.NextValue < source.Stop
                return false
        }

        value := this.NextValue
        this.NextValue += source.Step
        source.Produced += 1
        return true
    }
}

class MapSource {
    __New(source, selector) {
        this.Source := source
        this.Selector := selector
    }

    __Enum(numVars) {
        return MapIterator(this.Source.__Enum(1), this.Selector)
    }
}

class MapIterator {
    __New(inner, selector) {
        this.Inner := inner
        this.Selector := selector
        this.Index := 0
    }

    Call(&value) {
        item := 0
        inner := this.Inner
        if !inner(&item)
            return false

        this.Index += 1
        value := this.Selector.Call(item, this.Index)
        return true
    }
}

class FilterSource {
    __New(source, predicate) {
        this.Source := source
        this.Predicate := predicate
    }

    __Enum(numVars) {
        return FilterIterator(this.Source.__Enum(1), this.Predicate)
    }
}

class FilterIterator {
    __New(inner, predicate) {
        this.Inner := inner
        this.Predicate := predicate
        this.Index := 0
    }

    Call(&value) {
        inner := this.Inner
        loop {
            item := 0
            if !inner(&item)
                return false

            this.Index += 1
            if this.Predicate.Call(item, this.Index) {
                value := item
                return true
            }
        }
    }
}

class TakeSource {
    __New(source, count) {
        this.Source := source
        this.Count := Max(0, count)
    }

    __Enum(numVars) {
        return TakeIterator(this.Source.__Enum(1), this.Count)
    }
}

class TakeIterator {
    __New(inner, count) {
        this.Inner := inner
        this.Remaining := count
    }

    Call(&value) {
        if this.Remaining <= 0
            return false

        inner := this.Inner
        if !inner(&value)
            return false

        this.Remaining -= 1
        return true
    }
}

class SkipSource {
    __New(source, count) {
        this.Source := source
        this.Count := Max(0, count)
    }

    __Enum(numVars) {
        return SkipIterator(this.Source.__Enum(1), this.Count)
    }
}

class SkipIterator {
    __New(inner, count) {
        this.Inner := inner
        this.Remaining := count
        this.Ready := false
    }

    Call(&value) {
        inner := this.Inner
        if !this.Ready {
            while this.Remaining > 0 {
                ignored := 0
                if !inner(&ignored)
                    return false
                this.Remaining -= 1
            }
            this.Ready := true
        }

        return inner(&value)
    }
}

class ScanSource {
    __New(source, seed, accumulator) {
        this.Source := source
        this.Seed := seed
        this.Accumulator := accumulator
    }

    __Enum(numVars) {
        return ScanIterator(this.Source.__Enum(1), this.Seed, this.Accumulator)
    }
}

class ScanIterator {
    __New(inner, seed, accumulator) {
        this.Inner := inner
        this.State := seed
        this.Accumulator := accumulator
        this.Index := 0
    }

    Call(&value) {
        item := 0
        inner := this.Inner
        if !inner(&item)
            return false

        this.Index += 1
        this.State := this.Accumulator.Call(this.State, item, this.Index)
        value := this.State
        return true
    }
}

class DistinctSource {
    __New(source, keySelector := unset) {
        this.Source := source
        this.HasSelector := IsSet(keySelector)
        this.KeySelector := this.HasSelector ? keySelector : 0
    }

    __Enum(numVars) {
        return DistinctIterator(this.Source.__Enum(1), this.HasSelector, this.KeySelector)
    }
}

class DistinctIterator {
    __New(inner, hasSelector, keySelector) {
        this.Inner := inner
        this.HasSelector := hasSelector
        this.KeySelector := keySelector
        this.Seen := Map()
        this.Index := 0
    }

    Call(&value) {
        inner := this.Inner
        loop {
            item := 0
            if !inner(&item)
                return false

            this.Index += 1
            key := this.HasSelector ? this.KeySelector.Call(item, this.Index) : item
            if this.Seen.Has(key)
                continue

            this.Seen[key] := true
            value := item
            return true
        }
    }
}

Join(values) {
    text := ""
    for value in values
        text .= (text = "" ? "" : ",") value
    return text
}

Print(text) {
    FileAppend(text "`n", "*")
}

range := RangeSource(1, 1)
result := (Query.From(range)
    .Map((value, index) => value * value)
    .Filter((value, index) => Mod(value, 3) = 0)
    .Scan(0, (total, value, index) => total + value)
    .Take(5)
    .ToArray())

Print("pipeline=" Join(result))
Print("source_produced=" range.Produced)

unique := (Query.From([1, 1, 2, 3, 2, 4, 4, 5])
    .Distinct()
    .Skip(1)
    .Take(3)
    .ToArray())
Print("distinct_slice=" Join(unique))

bounded := Query.Range(10, -2, 2).ToArray()
Print("descending=" Join(bounded))

; Expected:
; pipeline=9,45,126,270,495
; source_produced=15
; distinct_slice=2,3,4
; descending=10,8,6,4,2
