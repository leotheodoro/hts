import HTSAPI
import HTSDomain
import HTSPersistence

// The generated API client is the sync transport. Declared here so HTSAPI and HTSPersistence stay independent.
extension APIClient: @retroactive SyncTransport {}
