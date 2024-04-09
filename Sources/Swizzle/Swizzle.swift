import Foundation

infix operator <->
infix operator <~>

public struct SwizzlePair: Hashable, CustomStringConvertible {
 public init(old: Selector, new: Selector, static: Bool = false) {
  self.old = old
  self.new = new
  self.static = `static`
 }

 public let old: Selector
 public let new: Selector
 public var `static` = false
 public var `operator`: String {
  self.static ? "<~>" : "<->"
 }

 public var description: String {
  "\(old) \(self.operator) \(new)"
 }
}

public extension Selector {
 static func <-> (lhs: Selector, rhs: Selector) -> SwizzlePair {
  SwizzlePair(old: lhs, new: rhs)
 }

 static func <-> (lhs: Selector, rhs: String) -> SwizzlePair {
  SwizzlePair(old: lhs, new: Selector(rhs))
 }

 static func <~> (lhs: Selector, rhs: Selector) -> SwizzlePair {
  SwizzlePair(old: lhs, new: rhs, static: true)
 }

 static func <~> (lhs: Selector, rhs: String) -> SwizzlePair {
  SwizzlePair(old: lhs, new: Selector(rhs), static: true)
 }
}

public extension String {
 static func <-> (lhs: String, rhs: Selector) -> SwizzlePair {
  SwizzlePair(old: Selector(lhs), new: rhs)
 }

 static func <~> (lhs: String, rhs: Selector) -> SwizzlePair {
  SwizzlePair(old: Selector(lhs), new: rhs, static: true)
 }
}

@resultBuilder
public enum SwizzlePairBuilder {
 @_alwaysEmitIntoClient
 public static func buildBlock(_ pairs: SwizzlePair...) -> [SwizzlePair] {
  pairs
 }
}

public protocol MethodSwizzle {
 var type: AnyObject.Type { get }
 var pairs: [SwizzlePair] { get }
 func callAsFunction() throws
}

public enum SwizzleError: LocalizedError {
 static let prefix: String = "Swizzle.Error: "
 case missingClass(_ name: String),
      missingMethod(
       _ type: AnyObject.Type, _ static: Bool, _ old: Bool, SwizzlePair
      )
 public var failureReason: String? {
  "\(Self.self): " + {
   switch self {
   case .missingClass(let type):
    "Missing class: \(type)"
   case .missingMethod(let type, let `static`, let old, let pair):
    """
    Missing \(old ? "old" : "new")\(`static` ? " static" : "") method for \
    \(type.description()): \(pair)
    """
   }
  }()
 }

 public var recoverySuggestion: String? {
  switch self {
  case .missingClass(let type):
   "Replace current object name: \(type), with an existing objc class"
  case .missingMethod(let type, let `static`, let old, let pair):
   """
   Create \(old ? "old" : "new")\(`static` ? " static" : "") method for \
   \(type.description()): \(pair)
   """
  }
 }
}

@resultBuilder
public enum Swizzler {
 @_alwaysEmitIntoClient
 public static func buildBlock(_ empty: ()) -> [Swizzle] { [] }
 @_alwaysEmitIntoClient
 public static func buildBlock(_ sets: Swizzle...) -> [Swizzle] { sets }
}

public extension MethodSwizzle {
 typealias Error = SwizzleError
 typealias PairBuilder = SwizzlePairBuilder
 typealias Builder = Swizzler
 typealias Result = [Swizzle]

 @_disfavoredOverload
 var type: AnyObject.Type { fatalError() }
 @_disfavoredOverload
 var pairs: [SwizzlePair] { fatalError() }

 func swizzle(pair: SwizzlePair) throws {
  guard
   let `class` =
   pair.static
    ? object_getClass(type)
    : type
  else {
   throw Error.missingClass(type.description())
  }
  guard
   let lhs =
   class_getInstanceMethod(`class`, pair.old) else {
   throw Error.missingMethod(`class`, pair.static, true, pair)
  }
  guard
   let rhs =
   class_getInstanceMethod(`class`, pair.new) else {
   throw Error.missingMethod(`class`, pair.static, false, pair)
  }

  if
   pair.static,
   class_addMethod(
    `class`, pair.old,
    method_getImplementation(rhs), method_getTypeEncoding(rhs)
   ) {
   class_replaceMethod(
    `class`,
    pair.new,
    method_getImplementation(lhs),
    method_getTypeEncoding(lhs)
   )
  } else {
   method_exchangeImplementations(lhs, rhs)
  }
 }

 func swizzle() throws {
  for pair in pairs {
   try swizzle(pair: pair)
  }
 }
}

public struct Swizzle: Hashable, MethodSwizzle {
 public let type: AnyObject.Type
 public let pairs: [SwizzlePair]

 init(type: AnyObject.Type, pairs: [SwizzlePair]) {
  self.type = type
  self.pairs = pairs
 }

 init(type: String, pairs: [SwizzlePair]) throws {
  guard let type = NSClassFromString(type) else {
   throw Error.missingClass(type)
  }
  self.type = type
  self.pairs = pairs
 }

 public init<A: AnyObject>(
  type: A.Type, @PairBuilder pairs: (A.Type) -> [SwizzlePair]
 ) {
  self.type = type
  self.pairs = pairs(type)
 }

 public init(
  type: (some AnyObject).Type, @PairBuilder pairs: () -> [SwizzlePair]
 ) {
  self.type = type
  self.pairs = pairs()
 }

 public init(type: String, @PairBuilder pairs: () -> [SwizzlePair]) throws {
  guard let type = NSClassFromString(type) else {
   throw Error.missingClass(type)
  }
  self.type = type
  self.pairs = pairs()
 }

 @discardableResult
 public init<A: AnyObject>(
  _ type: A.Type, @PairBuilder pairs: (A.Type) -> [SwizzlePair]
 ) throws {
  self.type = type
  self.pairs = pairs(type)
  try callAsFunction()
 }

 @discardableResult
 public init(
  _ type: (some AnyObject).Type, @PairBuilder pairs: () -> [SwizzlePair]
 ) throws {
  self.type = type
  self.pairs = pairs()
  try callAsFunction()
 }

 @discardableResult
 public init(_ type: String, @PairBuilder pairs: () -> [SwizzlePair]) throws {
  guard let type = NSClassFromString(type) else {
   throw Error.missingClass(type)
  }
  self.type = type
  self.pairs = pairs()
  try callAsFunction()
 }

 public func hash(into hasher: inout Hasher) {
  hasher.combine(ObjectIdentifier(type))
  hasher.combine(pairs)
 }

 public static func == (lhs: Swizzle, rhs: Swizzle) -> Bool {
  ObjectIdentifier(lhs.type) == ObjectIdentifier(rhs.type) &&
   lhs.pairs == rhs.pairs
 }

 @inline(__always)
 public func callAsFunction() throws {
  try swizzle()
 }
}

extension [Swizzle]: MethodSwizzle {
 @inline(__always)
 public func callAsFunction() throws {
  for set in self {
   try set.swizzle()
  }
 }
}
