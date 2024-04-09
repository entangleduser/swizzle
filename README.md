### Simple method swizzling, using result builders
The idea of using result builders and operators, was initially shared with [SwizzleSwift](https://github.com/MarioIannotta/SwizzleSwift). This is an extended implementation, designed to be more transparent when defining classes and static variants, and throwing by default.

#### Normal method swizzle
```swift
try Swizzle(<#A.Self#>) {
 <#SelectorA#> <-> // swizzle operator
  <#SelectorB#> // new method 
}
```

#### Static method swizzle
```swift
try Swizzle(<#A.Self#>) {
 <#SelectorA#> <~> <#SelectorB#>
}
```
> [!IMPORTANT]
> The static variant uses the operator `<~>` instead of `<->`    

#### Static method swizzle with passing type
```swift
try Swizzle(<#A.Self#>) { A in
 #selector(A.<#MethodA#>) <~>
  #selector(A.<#MethodB#>)
}
```

#### Static method swizzle with anonymous argument
```swift
try Swizzle(<#A.Self#>) {
 #selector($0.<#MethodA#>) <~>
  #selector($0.<#MethodB#>)
}
```
> [!NOTE]
> Any number of swizle pairs can be implemented within a given closure 

