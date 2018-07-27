public protocol Hash {
    static var littleEndian: Bool { get }
    static var chunkSize: Int { get }
    static var digestSize: Int { get }
    
    var hash: [UInt8] { get }
    
    mutating func reset()
    mutating func update(from pointer: UnsafePointer<UInt8>)
}

extension Hash {
    public mutating func hash(_ data: UnsafeBufferPointer<UInt8>) -> [UInt8] {
        var offset = 0
        let limit = data.count
        
        while offset < limit {
            self.update(from: data.baseAddress!.advanced(by: offset))
            
            offset = offset &+ Self.chunkSize
        }
        
        let result = self.hash
        self.reset()
        return result
    }
    
    public mutating func hash(bytes data: [UInt8]) -> [UInt8] {
        return self.hash(data, count: data.count)
    }
    
    public mutating func hash(_ data: UnsafePointer<UInt8>, count: Int) -> [UInt8] {
        let buffer = UnsafeBufferPointer(start: data, count: count)
        
        return hash(buffer)
    }
}
