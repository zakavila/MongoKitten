import BSON
import NIO

public struct AggregateCommand: MongoDBCommand {
    typealias Reply = CursorReply
    
    internal var namespace: Namespace {
        return aggregate
    }
    
    internal let aggregate: Namespace
    public var pipeline: [Document]
    public var cursor = CursorSettings()
    
    static var writing =  false
    static var emitsCursor = true
    
    public init<O>(pipeline: Pipeline<O>, in collection: Collection) {
        self.aggregate = collection.reference
        self.pipeline = pipeline.stages
    }
}

public final class AggregateCursor: QueryCursor {
    public typealias Element = Document
    
    public var batchSize = 101
    public let collection: Collection
    private var operation: AggregateCommand
    public private(set) var didExecute = false
    
    public init(operation: AggregateCommand, on collection: Collection) {
        self.operation = operation
        self.collection = collection
    }
    
    public func execute() -> EventLoopFuture<FinalizedCursor<AggregateCursor>> {
        return self.collection.connection.execute(command: self.operation).mapToResult(for: collection).map { cursor in
            return FinalizedCursor(basedOn: self, cursor: cursor)
        }
    }
    
    public func setBatchSize(_ batchSize: Int) -> AggregateCursor {
        self.batchSize = batchSize
        return self
    }
    
    public func transformElement(_ element: Document) throws -> Document {
        return element
    }
    
    public func limit(_ limit: Int) -> AggregateCursor {
        operation.pipeline.append(LimitStage(limit: limit).document)
        return self
    }
    
    public func skip(_ skip: Int) -> AggregateCursor {
        operation.pipeline.append(LimitStage(limit: skip).document)
        return self
    }
    
    public func project(_ projection: Projection) -> AggregateCursor {
        operation.pipeline.append(ProjectStage(projection: projection).document)
        return self
    }
    
    public func sort(_ sort: Sort) -> AggregateCursor {
        operation.pipeline.append(SortStage(sort: sort).document)
        return self
    }
}
