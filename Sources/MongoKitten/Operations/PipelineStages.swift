import NIO

public protocol AggregationPipeline : Encodable {
    associatedtype Output
    
    func readOutput(from cursor: FinalizedCursor<AggregateCursor>) -> Output
}

public protocol PipelineStage: Encodable {
    associatedtype Output
    
    func readOutput(from cursor: FinalizedCursor<AggregateCursor>) -> EventLoopFuture<Output>
}

public struct Pipeline<Output>: Encodable {
    typealias Transform = (FinalizedCursor<AggregateCursor>) -> EventLoopFuture<Output>
    
    public var stages: [Document]
    internal var transform: Transform
    
    public func encode(to encoder: Encoder) throws {
        try self.stages.encode(to: encoder)
    }
    
    fileprivate init(stages: [Document], transform: @escaping Transform) {
        self.stages = stages
        self.transform = transform
    }
    
    public func adding<Stage: PipelineStage>(
        stage: Stage
    ) throws -> Pipeline<Stage.Output> {
        let newStage = try BSONEncoder().encode(stage)
        return Pipeline<Stage.Output>(
            stages: self.stages + [newStage],
            transform: stage.readOutput
        )
    }
}

extension Pipeline where Output == FinalizedCursor<AggregateCursor> {
    public init() {
        self.init(stages: []) { cursor in
            return cursor.base.collection.eventLoop.newSucceededFuture(result: cursor)
        }
    }
}

public struct MatchStage: PipelineStage {
    public typealias Output = FinalizedCursor<AggregateCursor>
    
    public enum CodingKeys: String, CodingKey {
        case query = "$match"
    }
    
    public var query: Query
}

extension Pipeline where Output == FinalizedCursor<AggregateCursor> {
    public func match(_ query: Query) throws -> Pipeline<FinalizedCursor<AggregateCursor>> {
        return try self.adding(stage: MatchStage(query: query))
    }
    
    public func limit(_ limit: Int) throws -> Pipeline<FinalizedCursor<AggregateCursor>> {
        return try self.adding(stage: LimitStage(limit: 1))
    }
    
    public func skip(_ skip: Int) throws -> Pipeline<FinalizedCursor<AggregateCursor>> {
        return try self.adding(stage: SkipStage(skip: 1))
    }
    
    public func project(_ projection: Projection) throws -> Pipeline<FinalizedCursor<AggregateCursor>> {
        return try self.adding(stage: ProjectStage(projection: projection))
    }
    
    public func sort(_ sort: Sort) throws -> Pipeline<FinalizedCursor<AggregateCursor>> {
        return try self.adding(stage: SortStage(sort: sort))
    }
    
    public func count(writingInto outputField: String) throws -> Pipeline<Int> {
        return try self.adding(stage: CountStage(writingInto: outputField))
    }
}

public struct LimitStage: PipelineStage {
    public typealias Output = FinalizedCursor<AggregateCursor>
    
    public enum CodingKeys: String, CodingKey {
        case limit = "$limit"
    }
    
    public var limit: Int
}

public struct SkipStage: PipelineStage {
    public typealias Output = FinalizedCursor<AggregateCursor>
    
    public enum CodingKeys: String, CodingKey {
        case skip = "$skip"
    }
    
    public var skip: Int
}

public struct ProjectStage: PipelineStage {
    public typealias Output = FinalizedCursor<AggregateCursor>
    
    public enum CodingKeys: String, CodingKey {
        case projection = "$project"
    }
    
    public var projection: Projection
}

public struct SortStage: PipelineStage {
    public typealias Output = FinalizedCursor<AggregateCursor>
    
    public enum CodingKeys: String, CodingKey {
        case sort = "$sort"
    }
    
    public var sort: Sort
}

public struct CountStage: PipelineStage {
    public typealias Output = Int
    
    public enum CodingKeys: String, CodingKey {
        case outputField = "$count"
    }
    
    public var outputField: String
    
    public init(writingInto outputField: String) {
        self.outputField = outputField
    }
    
    public func readOutput(from cursor: FinalizedCursor<AggregateCursor>) -> EventLoopFuture<Int> {
        return cursor.singleDocument().thenThrowing { doc in
            switch doc[self.outputField] {
            case let int as Int32:
                return numericCast(int)
            case let int as Int64:
                #if arch(x86_64)
                    // Int == Int64, don't do boundary checking
                    return numericCast(int)
                #else
                    // Swift will handle safe conversion
                    return Int(int)
                #endif
            default:
                throw MongoKittenError(.unexpectedAggregateResults, reason: .unexpectedValue)
            }
        }
    }
}

internal extension PipelineStage {
    var document: Document {
        return try! BSONEncoder().encode(self)
    }
}

extension PipelineStage where Output == FinalizedCursor<AggregateCursor> {
    public func readOutput(from cursor: FinalizedCursor<AggregateCursor>) -> EventLoopFuture<FinalizedCursor<AggregateCursor>> {
        return cursor.base.collection.eventLoop.newSucceededFuture(result: cursor)
    }
}

internal extension FinalizedCursor where Base.Element == Document {
    func singleDocument() -> EventLoopFuture<Document> {
        return self.nextBatch().thenThrowing { batch -> Document in
            guard batch.isLast && batch.batch.count == 1 else {
                let reason: MongoKittenError.Reason
                
                if batch.batch.count == 0 {
                    reason = .noResultDocuments
                } else {
                    reason = .multipleResultDocuments
                }
                
                throw MongoKittenError(.unexpectedAggregateResults, reason: reason)
            }
            
            return batch.batch[0]
        }
    }
}
