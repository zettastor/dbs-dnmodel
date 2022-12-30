/**
 * The first thing to know about are types. The available types in Thrift are:
 *
 *  bool        Boolean, one byte
 *  byte        Signed byte
 *  i16         Signed 16-bit integer
 *  i32         Signed 32-bit integer
 *  i64         Signed 64-bit integer
 *  double      64-bit floating point value
 *  string      String
 *  binary      Blob (byte array)
 *  map<t1,t2>  Map from one type to another
 *  list<t1>    Ordered list of one type
 *  set<t1>     Set of unique elements of one type
 *
 * Did you also notice that Thrift supports C style comments?
 */

include "shared.thrift"

/**
 * This thrift file define storage service and its client
 */
namespace java py.thrift.datanode.service

/**
 * Enum definition 
 *
 */
enum BroadcastTypeThrift {
    WriteMutationLog = 1, // Writing logs to other nodes
    AddOrRemoveMember = 2, // Primary notifies secondaries there is a change in the membership (Generation # changed)
    VotePrimaryPhase1 = 3, // The 1a step (proposal) to vote the new primary
    VotePrimaryPhase2 = 4, // The 2a step (accept) to vote the new primary
    ExtendLease = 5, // Extend primary lease.
    GiveMeYourLogs = 6, // request all logs after certain pointer.
    CatchUpMyLogs = 7, // The pre-primary asks SecondaryEnrolled to catch up its all logs
    JoinMe = 8, // The primary asks SecondaryEnrolled to join the group
    GiveMeYourMembership = 9, // the coordinator asks all members in the group to give it membership
    DeleteSegmentUnit = 10, // Delete segment unit
    UpdateSegmentUnitVolumeMetadataJson = 11, // Update segment unit
    BroadcastAbortedLogs = 12, // Correct a page
    WriteMutationLogs = 13, // Writing logs to other nodes
    StepIntoSecondaryEnrolled = 14, // Primary notify candidate secondary in moderate selected status change Secondary enrolled status
    BroadcastLogResults=15, // Coordinate broadcast log results to datanodes time to time
    GiveYouLogId=16, //
    CollectLogsInfo=17,
    PrimaryChanged=18, // the old primary notifies secondaries that the primary candidate is ready to be primary
    GetPrimaryMaxLogId=19, // get pirmary max log id and pcl, for secondary rollback.
    CheckSecondaryIfFullCopyIsRequired=20, // check if secondary copy page requires a full copy
    StartBecomePrimary=21,
}

enum LogSyncActionThrift {
    // the primary has committed the log
    Exist = 1,

    // the primary thinks the log is missing in the secondary. The secondary should add this log
    Add = 2,

    // the primary thinks the log is missing in secondary and the secondary only need the metadata of the log, mainly
    // for copying page.
    AddMetadata = 3,

    // the primary doesn't have the log that the secondary has. The secondary should drop the log to the floor
    Missing = 4
}

enum LogStatusThrift {
    Committed = 1, // the primary has committed the log
    Aborted = 2, // the primary has aborted the log
    Created = 3, // the primary doesn't know the status yet.
    AbortedConfirmed = 4 // the majority of secondaries have confirmed aborted log
}

// Describe whether something has been done or still in progress
enum ProgressThrift {
    InProgress = 1,
    Done = 2
}

// Describe why write mutation log failed 
enum WriteMutationLogFailReasonThrift {
    OutOfMemory = 1,    // fast buffer exhausted
    UnknownReason = 2  // reason unknown
}

struct AbortedLogThrift {
    1: i64 logUuid,
    2: i64 logId,
    3: i64 offset,
    4: i32 length,
    5: i64 checksum,
}

/**
 * Requests and Responses
 */

//*************************Read Request sent from coordinator to the primary********************
struct ReadRequestUnit {
    1: i64 offset,
    2: i32 length,
    3: i64 requestId
    4: optional bool merged
    5: optional bool filled
}

struct ReadRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: list<ReadRequestUnit> requestUnits,
    5: optional shared.SegmentMembershipThrift membership,
    6: optional bool fromInternal,
    7: optional i32 snapshotId
}

struct ReadResponseUnit {
    1: i64 offset,
    2: i32 length,
    3: shared.ReadUnitResultThrift result,
    4: optional binary data,
    5: optional i64 checksum,
    6: i64 requestId
}

struct ReadResponse {
    1:i64 requestId,
    2:list<ReadResponseUnit> responseUnits,
    3:optional shared.SegmentMembershipThrift membership
}


//****************************End of Read Request *****/


//****************************Write Request sent from coordinator to the primary *****/
struct WriteRequestUnit {
    1: i64 logUuid,
    2: i64 logId,
    3: i64 offset, // the logic offset at the volume
    4: binary data,
    5: i64 checksum
    6: i64 requestId
    7: optional bool merged
}

struct WriteResponseUnit {
    1: i64 offset, // the logic offset at the volume
    2: i32 length,
    3: shared.WriteUnitResultThrift result,
    4: i64 requestId
}

struct WriteRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: list<WriteRequestUnit> requestUnits,
    5: i32 snapshotVersion   // the latest snapshot version
    6: optional shared.SegmentMembershipThrift membership
}

struct WriteResponse {
    1: i64 requestId,
    2: optional list<WriteResponseUnit> responeseUnits,
    3: optional shared.SegmentMembershipThrift membership
}
//******** End of Write Request *****/

//********** Create Segment Request ******************************/
struct CreateSegmentUnitRequest{
   1: i64 requestId,
   2: i64 volumeId, 
   3: i32 segIndex,
   4: shared.VolumeTypeThrift volumeType,
   6: optional string volumeMetadataJson,
   7: optional string accountMetadataJson,
   8: optional shared.SegmentMembershipThrift initMembership, // the initial membership, used by a new node trying to join an existing group
   9: optional list<i64> initMembers, // the initial members, used by new nodes to create a brand new volume. If initMembership is set too, 
   // then initMembership has higher preference to initMembers.
   11: optional shared.SegmentMembershipThrift srcMembership, // the membership for src volume from which the clone volume copy page
   14: i64 storagePoolId,
   15: shared.SegmentUnitTypeThrift segmentUnitType,
   16: optional bool secondaryCandidate,
   17: optional i64 replacee,
   18: i32 segmentWrapSize,
   20: bool enableLaunchMultiDrivers,
   21: shared.VolumeSourceThrift volumeSource
}

struct CreateSegmentUnitResponse{
    1: i64 requestId
}

struct CreateSegmentUnitNode {
   1: i32 segIndex,
   2: optional shared.SegmentMembershipThrift initMembership, // the initial membership, used by a new node trying to join an existing group
   3: optional list<i64> initMembers, // the initial members, used by new nodes to create a brand new volume. If initMembership is set too, 
   // then initMembership has higher preference to initMembers.
   5: optional shared.SegmentMembershipThrift srcMembership, // the membership for src volume from which the clone volume copy page
   8: shared.SegmentUnitTypeThrift segmentUnitType,
   9: optional bool secondaryCandidate,
   10: optional i64 replacee,
   11: i32 segmentWrapSize,
   12: shared.VolumeSourceThrift volumeSource,
}

struct CreateSegmentUnitBatchRequest {
   1: i64 requestId,
   2: i64 volumeId, 
   3: shared.VolumeTypeThrift volumeType,
   5: optional string volumeMetadataJson,
   6: optional string accountMetadataJson,
   7: i64 storagePoolId,
   9: bool enableLaunchMultiDrivers,
   10: list<CreateSegmentUnitNode> segmentUnits,
}

enum CreateSegmentUnitFailedCodeThrift {
    UnknownException=1,
    NotEnoughSpaceException=2,
    SegmentExistingException=3,
    NoMemberException=4,
    ServiceHavingBeenShutdown=5,
    SegmentUnitBeingDeletedException=6,
    SegmentOfflinedException=7,
}

struct CreateSegmentUnitFailedNode {
    1: i32 segIndex,
    2: CreateSegmentUnitFailedCodeThrift errorCode,
}

struct CreateSegmentUnitBatchResponse {
   1: i64 requestId,
   2: i64 volumeId,
   3: list<i32> successedSegs,
   4: list<CreateSegmentUnitFailedNode> failedSegs,
}

//******** End of CreateSegmentUnitRequest *****/

//********** Delete Segment unit Request ******************************/
struct DeleteSegmentUnitRequest{
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: shared.SegmentMembershipThrift membership,
    5: optional bool synPersist = true, // if true, sync persist metadata, else async persist metadata
}

struct DeleteSegmentUnitResponse{
    1: i64 requestId
}

//********** Delete Segment Request ******************************/
struct DeleteSegmentRequest{
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: shared.SegmentMembershipThrift membership
}

struct DeleteSegmentResponse{
    1: i64 requestId
}

//********** Sync logs request sent from a secondary to the primary when the secondary is active **********/
struct SyncLogsRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    // the last persisted log. In fact, it is a log id
    4: i64 ppl,

    // the last committed log. In fact, it is a log id. The reason to have pcl is there might be some missing logs
    // between pcl and the first log in the logsAfterCL
    5: i64 pcl,

    // ids of all logs after the last committed log.
    6: list<i64> logsAfterCl,

    7: list<i64> uuidsOfLogsWithoutLogId,
    8: shared.SegmentMembershipThrift membership,
    9: i64 myself,

    // request segment unit state
    10: shared.SegmentUnitStatusThrift requestSegmentUnitStatus,

    // when segment unit status is pre-secondary, all logs which are committed in primary but missing in secondary should
    // be carried to pre-secondary without data, pre-secondary will set the log to be applied and persisted.
    11: optional i64 catchUpLogId,

    12: optional i64 preprimarySid,
}

// For SyncLogsResponse 
struct LogInfoThrift {
    // write data request
    1: i64 offset,
    2: i64 checksum,
    3: i32 length,
    6: optional binary data
}

// For SyncLogsResponse 
struct LogThrift {
    1: i64 logUuid,
    2: i64 logId,
    3: LogSyncActionThrift action, //After receiving the log, how the secondary deals with the log
    4: LogStatusThrift status, //After receiving the log, how the secondary deals with the log
    5: optional LogInfoThrift logInfo //the log information is not null only if the log action is add
} 

// For SyncLogsResponse
struct ExistingLogsThrift {
    1: i32 confirmedSize,
    2: list<i64> bitMapForLogIds,
    3: list<i64> bitMapForCommitted,
    4: list<i64> bitMapForAbortedConfirmed
}

struct SyncLogsResponse {
    1: i64 requestId,
    2: i64 pswpl, //segment wide persisted log
    3: i64 pswcl, //segment wide persisted log
    4: i64 primaryClId,
    5: map<i64, i64> mapUuidToLogId,
    6: list<LogThrift> missingLogsAtSecondary, // missing logs which primary has but secondary doesn't. They are sorted by their log ids
    7: ExistingLogsThrift existingLogs, // existing logs of request to primary
    8: optional shared.SegmentMembershipThrift latestMembership
}

//********** End of Sync logs request  ******************/

//********** Catch up logs sent from a secondary to the primary when the secondary is in PreSecondary status **********/
struct SecondaryCopyPagesRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: i64 ppl, // the last persisted log. In fact, it is a log id
    5: i64 pcl, // the last committed log. In fact, it is a log id
    6: shared.SegmentMembershipThrift membership,
    7: i64 myself,
    8: i64 preprimarySid,
    9: bool forceFullCopy,
}

struct InitiateCopyPageRequestThrift {
    1: i64 requestId,
    2: i64 preprimarySid,
    3: i64 volumeId,
    4: i32 segIndex,
    5: i64 sessionId,
    6: shared.SegmentMembershipThrift membership,
    7: i64 myself,
    8: i64 catchUpLogId
    9: i32 maxSnapshotId,
}

struct SecondaryCopyPagesResponse {
    1: i64 requestId,
    2: bool secondaryClIdExistInPrimary,
    //id of segment wide persisted log
    3: i64 pswpl,
    //id of segment wide committed log
    4: i64 pswcl,
    5: i64 maxLogId,
    6: LogThrift catchUpLogFromPrimary,
    7: shared.SegmentMembershipThrift membership,
    8: optional binary semgentUnitFreePageBitmap,
}

struct InitiateCopyPageResponseThrift {
    1: i64 requestId,
    2: i64 sessionId,
    // 1, wait for the plal of primary to catch up catch-up-log
    // 2, the archive which segment unit belongs to has too many segment units which are migrating, the current
    // segment unit will be paused untils some one has finished.
    3: bool canStart
    4: i32 waitTimeToRetry
}

struct PageAddressThrift {
    1: i64 volumeId,
    2: i32 segIndex,
    3: i64 segUnitOffsetInArchive,
    4: i64 offsetInSegment,
}

struct DataPageThrift {
    1: i32 pageIndex, // page index
    2: binary data,
    3: i64 checksum,
    5: optional PageAddressThrift pageAddressOfLastSent,
}

//********** The requests that update segment unit metadata */
// Update segment unit's membership and status
struct UpdateSegmentUnitMembershipAndStatusRequest{
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: shared.SegmentMembershipThrift membership,
    5: optional shared.SegmentMembershipThrift newMembership,
    6: optional string status,
    7: optional string volumeMetadataJson,
    8: optional bool broadcast
}

struct UpdateSegmentUnitMembershipAndStatusResponse{
    1: i64 requestId
}

// update segment unit's volumeMetadataJson. This request only
// goes to the primary of the segment group. 
struct UpdateSegmentUnitVolumeMetadataJsonRequest{
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: shared.SegmentMembershipThrift membership,
    5: string volumeMetadataJson
}

struct UpdateSegmentUnitVolumeMetadataJsonResponse{
    1: i64 requestId
}

//********** End of Update segment unit metadata request ******************/

//********** Arbiter pokes primary ******************/
struct ArbiterPokePrimaryRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: shared.SegmentMembershipThrift membership,
    5: shared.SegmentUnitStatusThrift requestSegmentUnitStatus, // request segment unit state
    6: i64 myself,
    7:optional i64 preprimarySid
}

struct ArbiterPokePrimaryResponse {
    1: i64 requestId,
    2: optional shared.SegmentMembershipThrift latestMembership
}

//********** PreSecondary/PreArbiter think it is ready to move on to Secondary/Arbiter ******************/
struct ImReadyToBeSecondaryRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: shared.SegmentMembershipThrift membership,
    5: i64 myself,
    6: optional bool secondaryCandidate,
    7: optional i64 replacee
}

struct ImReadyToBeSecondaryResponse {
    1: i64 requestId,
    2: optional shared.SegmentMembershipThrift latestMembership
}

//********** Broadcast request sent from the primary to all secondaries ******************/
struct BroadcastRequest {
    1: i64 requestId,
    // for VotePrimaryPhase1 request, logId is the N
    2: i64 logId,
    3: i64 volumeId,
    4: i32 segIndex,
    5: BroadcastTypeThrift logType,
    6: shared.SegmentMembershipThrift membership,
    7: optional i64 myself,

    // for writeData log
    8: optional i64 offset,
    9: optional binary data,
    10: optional i64 cloneVolumeDataOffset,
    11: optional i32 cloneVolumeDataLength,
    12: optional i64 checksum,
    13: optional list<AbortedLogThrift> abortedLogs, // all aborted logs prior to the current log

    // for VotePrimaryPhase2 request, value is the primary id that is being chosen
    14: optional shared.SegmentMembershipThrift proposalValue,

    // For GiveMeYourLogs request
    15: optional i64 token,
    16: optional map<i64, i64> receivedLogIdMap, // map for logId with different secondary, key is the instance id, value is log id

    // For welcomeToGroup and JoinMe
    17: optional i64 pswpl,
    18: optional i64 pswcl,

    // For update segment unit volume metadata json
    19: optional string volumeMetadataJson,

    // For write a list of logs
    20: optional list<LogThrift> logs,
    21: optional i64 pcl, // for CatchUpMyLogs

    // For coordinate broadcast log results
    22: optional shared.CommitLogsRequestThrift commitLogsRequest,


    23: optional bool mergeLogs, // for broadcasting merged logs

    24: optional i64 preprimarySid
    26: optional LogStatusThrift status

    // For GiveYouLogId request
    27: optional i64 logUuid,
    28: optional map<i64, i64> logUuidToLogId,

    29: optional list<i64> logIdsAlreadyHave,

    // for vote primary
    30: optional i32 proposalNum,
    31: optional i32 minProposalNum;
}

struct BroadcastResponse {
    1: i64 requestId,
    2: i64 myInstanceId,
    3: optional i64 maxLogId,
    4: optional shared.SegmentMembershipThrift membership,
    // response for VotePrimaryPhase1 request, the pcl is the pointer to committed log
    5: optional i64 acceptedN, // the N that is associated with the accepted value
    6: optional shared.SegmentMembershipThrift acceptedValue, // the accepted primary id
    7: optional i64 ppl,
    8: optional i64 pcl,
    9: optional list<LogThrift> logs, // all logs requested by GiveMeYourLogs request
    10: optional binary data, // for Correct Page
    11: optional i64 checksum, // for Correct Page
    12: optional string volumeMetadataJson, // for update volume metadata
    13: optional ProgressThrift progress,
    14: optional shared.SegmentUnitStatusThrift myStatus, // segment unit state at myself
    15: optional shared.CommitLogsResponseThrift commitLogsResponse, // coordinate get response from datanode
    16: optional bool isSecondaryZombie, // for deciding whether we need the temp primary to become the new primary
    17: optional i64 latestValueOfLogIdGenerator,
    18: optional i64 tempPrimary,
    19: optional bool arbiter,
    20: optional bool migrating,
    21: optional bool forceFullCopy;
}


struct InvalidateCacheRequest {
    1: i64 magicNumber,
    2: i32 cacheLevel
}

struct InvalidateCacheResponse {
    1: bool done
}

struct ReleaseAllLogsRequest {
    1: i64 magicNumber,
}

struct ReleaseAllLogsResponse {
}

//********** End of Broadcast request ******************/

struct MakePrimaryDecisionResponse {
    1:i64 requestId
}

struct MakePrimaryDecisionRequest {
    1:i64 requestId,
    2:i64 volumeId,
    3:i32 segIndex,
    4:shared.SegmentMembershipThrift latestMembership,
    5:i64 instanceIdOfPrimaryDecider,
    6:i64 acceptedN,
    7:optional i64 myself
}

//********** The request to kick off the potential primary sent from the moderator ******************/
struct KickOffPotentialPrimaryRequest {
    1:i64 requestId,
    2:i64 volumeId,
    3:i32 segIndex,
    4:shared.SegmentMembershipThrift latestMembership,
    5:i64 potentialPrimaryId,
    6:optional i64 acceptedN, // use the N to indicate that the potentialPrimary is elected by the acceptedN.
    //This is in case there is another election process that have
    7:optional i64 myself,
    8:i32 priority, // the become primary priority
}

struct KickOffPotentialPrimaryResponse{
    1:i64 requestId
}
//********** End of Kicking Request  *************/


//********** Joining Group Request sent from an inactive secondary to the primary ******************/
struct JoiningGroupRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: shared.SegmentMembershipThrift membership,
    5: i64 myself,
    6: i64 ppl,
    7: i64 pcl,
    8: bool arbiter,
    9: optional bool secondaryCandidate,
   10: optional i64 replacee
}

struct JoiningGroupResponse {
    1:i64 requestId,
    2:shared.SegmentMembershipThrift membership, // it is ok to join the group, but please update your membership
    3:i64 sfal // sync logs up to sfal (my current max log ID)
}
//********** End of Joining Group Request  *************/

//********** For host heartbeat ***********//
struct HeartbeatRequestUnit {
    1: i64 volumeId,
    2: i32 segIndex,
    3: i32 epoch,
    4: i64 pcl,
    5: bool prePrimary;
}

struct HeartbeatRequest {
    1: i64 requestId,
    2: list<HeartbeatRequestUnit> heartbeatRequestUnits
}

// abnormal result when lease extend
enum HeartbeatResultThrift {
    Success=1,
    StaleMembership=2,
    InvalidMembership=3,
    InvalidSegmentUnitStatus =4,
    LeaseExtensionFrozen=5,
    LeaseExpired=6,
    SegmentNotFound=7
}

struct HeartbeatResponseUnit {
    1: i64 volumeId,
    2: i32 segIndex,
    3: HeartbeatResultThrift result,
    4: optional i32 EpochInSecondary
}

struct HeartbeatResponse {
    1: i64 requestId,
    2: list<HeartbeatResponseUnit> heartbeatResponseUnits
}

struct PushPageRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: shared.SegmentMembershipThrift membership,
    5: list<DataPageThrift> pages,
    6: optional bool allPagePushed, // mark all the pages has been pushed
}

struct PushPageResponse {
    1: i64 requestId,
}

struct CheckSecondaryHasAllLogRequest {
    1:i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
}

struct CheckSecondaryHasAllLogResponse {
    1:i64 requestId,
    2:bool hasAllLog,
}
//*******End of host heartbeat**************//

//************For Sync Shadow Pages**************//
struct ShadowPageThrift {
    1: bool empty,
    2: i64 volumeId,
    3: i32 segIndex,
    4: i32 originalPageIndex,
    5: i32 snapshotId,
    6: i64 snapshotCreatedTime,
    7: binary data;
}

struct SyncShadowPagesRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: i64 startLogId,
    5: i64 endLogId,
    6: shared.SegmentMembershipThrift membership,
    7: i64 myself,
    8: optional i64 preprimarySid,
    9: optional i32 snapshotVersion,
    10: optional bool inRollbackProgress,
}

struct SyncShadowPagesResponse {
    1: i64 requestId,
    2: i64 primaryMaxLogId;
    3: list<i64> logIdsInOrder,
    4: list<ShadowPageThrift> shadowPagesInOrder,
}
//**********End of Sync Shadow Pages**************//

struct CheckSecondaryReachableRequest {
    1: i64 requestId,
    2: shared.SegIdThrift segId,
    3: shared.SegmentMembershipThrift membership,
    4: i64 secondaryInstanceId,
}

struct CheckPrimaryReachableResponse {
    1: bool reachable,
    2: i64 pcl,
}

struct CheckSecondaryReachableResponse {
    1: i64 requestId,
    3: bool secondaryReachable,
    2: optional shared.SegmentMembershipThrift newMembership,
}

struct ConfirmPrimaryUnreachableRequest {
    1: i64 requestId,
    2: shared.SegIdThrift segId,
    3: i64 tempPrimary,
    4: shared.SegmentMembershipThrift membership,
}

struct ConfirmPrimaryUnreachableResponse {
    1: i64 requestId,
    2: optional shared.SegmentMembershipThrift newMembership
}

//************For Retrieve BitMap**************//
struct RetrieveBitMapRequest {
   1: i64 requestId,
   2: shared.SegIdThrift segId,
   3: i64 archiveId,
   4: i64 myInstanceId,
   5: bool onSameArchive
}

struct RetrieveBitMapResponse {
   1: i64 requestId,
   2: binary bitMapInBytes,
   3: optional shared.SegmentMembershipThrift latestMembrship
}

//************For Save Database Info**************//
struct BackupDatabaseInfoRequest {
    1: i64 requestId,
    2: shared.ReportDbResponseThrift databaseInfo
}

struct BackupDatabaseInfoResponse {
    1: i64 requestId
}

struct InnerMigrateSegmentUnitRequest {
   1: i64 requestId,
   2: shared.SegIdThrift segId,
   3: i64 targetArchiveId
}

struct InnerMigrateSegmentUnitResponse {
   1: i64 requestId,
}

struct MigratePrimaryRequest {
   1: i64 requestId,
   2: i64 primaryCandidate,
   3: shared.SegIdThrift segId,
}

struct MigratePrimaryResponse {
   1: i64 requestId,
}

struct CanYouBecomePrimaryRequest {
   1: i64 requestId,
   2: shared.SegIdThrift segId,
   3: shared.SegmentMembershipThrift membership,
}

struct CanYouBecomePrimaryResponse {
   1: i64 requestId,
   2: bool everythingOk,
}

struct ImReadyToBePrimaryRequest {
   1: i64 requestId,
   2: shared.SegmentMembershipThrift membership,
   3: i64 myClId,
   4: i64 myself,
   5: shared.SegIdThrift segId,
}

struct ImReadyToBePrimaryResponse {
   1: i64 requestId,
   2: shared.SegmentMembershipThrift newMembership,
}

struct DepartFromMembershipRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,
    4: shared.SegmentMembershipThrift membership,
    5: i64 instanceId,
    6: optional bool synPersist = true, //if true, async persist metadata, else async persist metadata.
}

struct DepartFromMembershipRespone {
    1: i64  requestId,
}

struct StartOnlineMigrationRequest {
    1: i64 requestId,
    2: i64 volumeId,
    3: i32 segIndex,

}

struct StartOnlineMigrationResponse {
    1: i64 requestId,
    2: bool result,
}

/**
 * Exception definition
**/
exception SegmentNotFoundExceptionThrift {
    1: optional string detail
}

exception OutOfRangeExceptionThrift {
    1: optional string detail
}

exception InputHasNoDataExceptionThrift {
    1: optional string detail
}

exception JoiningGroupRequestDeniedExceptionThrift {
    1: optional string detail
}

exception InvalidSegmentUnitStatusExceptionThrift {
    1: optional string detail,
    2: optional shared.SegmentUnitStatusThrift myStatus
    3: optional shared.SegmentMembershipThrift membership
}

exception PrimaryIsRollingBackExceptionThrift {
    1: optional string detail
}

exception PrimaryNeedRollBackFirstExceptionThrift {
    1: optional string detail
}

// the token associated with the potential primary is invalid
exception InvalidTokenThrift {
    1: optional string detail
}

exception WriteMutationLogExceptionThrift {
    1: optional string detail,
    2: optional bool abortLogSuccess,
    3: optional WriteMutationLogFailReasonThrift reason

}

exception AbortMutationLogExceptionThrift {
    1: optional string detail
}

// the log has inappropriate log status, e.g., the log to be written is committed but 
// a log with the same log id has a start status. (usually at the processMutationLog broadcast)
exception InappropriateLogStatusExceptionThrift {
    1: optional string detail
}

// Failed to broadcast to other members
exception FailedToBroadcastExceptionThrift {
    1: optional string detail,
    2: optional i64 logId
}

// The lease at a secondary can't be extended
exception LeaseExtensionFrozenExceptionThrift {
    1: optional string detail
}

// PreSecondary is not at the proper session with the preprimary
exception WrongPrePrimarySessionExceptionThrift {
    1: optional string detail
}

// Secondary is syncing logs from the PrePrimary who is transienting to Primary
exception StillAtPrePrimaryExceptionThrift {
    1: optional string detail
}

// Not supported 
exception NotSupportedExceptionThrift{
    1: optional string detail
}

exception FailedToKickOffPrimaryExceptionThrift {
    1: optional string detail
}

exception NoAvailableCandidatesForNewPrimaryExceptionThrift {
    1: optional string detail
}

exception RefuseDepartFromMembershipExceptionThrift{
    1: optional string detail
}

exception InitializeBitmapExceptionThrift {
    1: optional string detail,
}

exception OnSameArchiveExceptionThrift {
    1: optional string detail
}

exception NoOneCanBeReplacedExceptionThrift {
    1: optional string detail
}

exception SecondarySnapshotVersionTooHighExceptionThrift {
    1: optional string detail
}

/**
 * The definition of the service that stores segments and data
 */
service DataNodeService extends shared.DebugConfigurator {

    // Healthy?
    void ping(),

    void shutdown(),

    ConfirmPrimaryUnreachableResponse confirmPrimaryUnreachable(1:ConfirmPrimaryUnreachableRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                             2:shared.ServiceHavingBeenShutdownThrift shbsd,
                             3:InvalidSegmentUnitStatusExceptionThrift isus,
                             4:shared.InternalErrorThrift ie),

    CheckPrimaryReachableResponse checkPrimaryReachable(1:shared.SegIdThrift segId, 2:shared.SegmentMembershipThrift membership) throws (1:SegmentNotFoundExceptionThrift snf,
                             2:shared.ServiceHavingBeenShutdownThrift shbsd,
                             3:InvalidSegmentUnitStatusExceptionThrift isus,
                             4:shared.InternalErrorThrift ie),

    CheckSecondaryReachableResponse checkSecondaryReachable(1:CheckSecondaryReachableRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                               2:shared.NotPrimaryExceptionThrift npm,
                               3:shared.ServiceHavingBeenShutdownThrift shbsd,
                               4:shared.InternalErrorThrift ie),

    // Add more exceptions here
    ReadResponse readData(1:ReadRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.NotPrimaryExceptionThrift npm,
                           3:shared.ServiceHavingBeenShutdownThrift shbsd,
                           4:shared.InternalErrorThrift ie),

    WriteResponse writeData(1:WriteRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.NotPrimaryExceptionThrift npm,
                           3:shared.NotSecondaryExceptionThrift nse,
                           4:shared.ResourceExhaustedExceptionThrift ree,
                           5:FailedToBroadcastExceptionThrift fb,
                           6:shared.ServiceHavingBeenShutdownThrift shbsd,
                           7:shared.InternalErrorThrift ie),

    // This API is used by a secondary to sync up the log with the primary
    SyncLogsResponse syncLogs(1:SyncLogsRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.LogIdTooSmallExceptionThrift lits, 
                           3:shared.StaleMembershipExceptionThrift sm,
                           4:shared.NotPrimaryExceptionThrift npe, 
                           5:shared.InvalidMembershipExceptionThrift ime,
                           6:shared.YouAreNotInMembershipExceptionThrift yanime,
                           7:WrongPrePrimarySessionExceptionThrift wppset,
                           8:StillAtPrePrimaryExceptionThrift sppet,
                           9:shared.InternalErrorThrift ie,
                           10:shared.ServiceHavingBeenShutdownThrift shbsd),

    ArbiterPokePrimaryResponse arbiterPokePrimary(1:ArbiterPokePrimaryRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           3:shared.StaleMembershipExceptionThrift sm,
                           4:shared.NotPrimaryExceptionThrift npe, 
                           5:shared.InvalidMembershipExceptionThrift ime,
                           6:shared.YouAreNotInMembershipExceptionThrift yanime,
                           7:WrongPrePrimarySessionExceptionThrift wppset,
                           8:shared.InternalErrorThrift ie,
                           9:shared.ServiceHavingBeenShutdownThrift shbsd),

    ImReadyToBeSecondaryResponse iAmReadyToBeSecondary(1:ImReadyToBeSecondaryRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           3:shared.StaleMembershipExceptionThrift sm,
                           4:shared.NotPrimaryExceptionThrift npe,
                           5:shared.InvalidMembershipExceptionThrift ime,
                           6:shared.YouAreNotInMembershipExceptionThrift yanime,
                           7:shared.InternalErrorThrift ie,
                           8:shared.ServiceHavingBeenShutdownThrift shbsd,
                           9:NoOneCanBeReplacedExceptionThrift nocbre),

    // This API is used by a secondary at PreSecondary status to catch up with the primary
    SecondaryCopyPagesResponse secondaryCopyPages(1:SecondaryCopyPagesRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.NotPrimaryExceptionThrift np, 
                           3:shared.StaleMembershipExceptionThrift sm,
                           5:shared.InvalidMembershipExceptionThrift ime,
                           6:shared.ServiceHavingBeenShutdownThrift shbsd,
                           7:shared.YouAreNotInMembershipExceptionThrift yanime,
                           8:WrongPrePrimarySessionExceptionThrift wppset,
                           9:shared.InternalErrorThrift ie,
                           10:SecondarySnapshotVersionTooHighExceptionThrift ssv,
                           11:PrimaryNeedRollBackFirstExceptionThrift pnrb),

    InitiateCopyPageResponseThrift initiateCopyPage(1:InitiateCopyPageRequestThrift request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.NotPrimaryExceptionThrift np, 
                           3:shared.StaleMembershipExceptionThrift sm,
                           5:shared.InvalidMembershipExceptionThrift ime,
                           6:shared.ServiceHavingBeenShutdownThrift shbsd,
                           7:shared.YouAreNotInMembershipExceptionThrift yanime,
                           8:WrongPrePrimarySessionExceptionThrift wppset,
                           9:PrimaryIsRollingBackExceptionThrift pirbe,
                           10:shared.ConnectionRefusedExceptionThrift cre),

    // Note that either initMembership or initMembers have to be set. Otherwise, NoMemberExceptionThrift is thrown
    // Also if both initMembership and initMembers are set, initMembers is ignored
    // if the segment unit has been deleted but it is still in Deleting status, the segment unit will be moved to deleted status
    // and a new segment unit with the same segId will be created. No membership will be checked even if the new membership is lower
    // than the membership in the deleting segment unit.
    CreateSegmentUnitResponse createSegmentUnit(1:CreateSegmentUnitRequest request) throws (1:shared.NotEnoughSpaceExceptionThrift nese,
                           2:shared.SegmentExistingExceptionThrift seet,
                           3:shared.NoMemberExceptionThrift nmet,
                           4:shared.ServiceHavingBeenShutdownThrift shbsd,
                           5:shared.SegmentUnitBeingDeletedExceptionThrift subdd,
                           6:shared.InternalErrorThrift ie,
                           7:shared.SegmentOfflinedExceptionThrift sol),

    CreateSegmentUnitBatchResponse createSegmentUnitBatch(1:CreateSegmentUnitBatchRequest request) throws (1:shared.NotEnoughSpaceExceptionThrift nese,
                           2:shared.SegmentExistingExceptionThrift seet,
                           3:shared.NoMemberExceptionThrift nmet,
                           4:shared.ServiceHavingBeenShutdownThrift shbsd,
                           5:shared.SegmentUnitBeingDeletedExceptionThrift subdd,
                           6:shared.InternalErrorThrift ie,
                           7:shared.SegmentOfflinedExceptionThrift sol),

    // Delete a segment unit.
    DeleteSegmentUnitResponse deleteSegmentUnit(1:DeleteSegmentUnitRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.ServiceHavingBeenShutdownThrift shbsd,
                           3:shared.StaleMembershipExceptionThrift sm,
                           4:shared.InternalErrorThrift ie),

    // Delete a segment. In other words, deleting all segment units in a segment.
    // The request can be only sent to the master of a segment unit. Otherwise,  always throws InvalidSegmentUnitStatusExceptionThrift when it receives a Delete
    // segment unit request.
    DeleteSegmentResponse deleteSegment(1:DeleteSegmentRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.ServiceHavingBeenShutdownThrift shbsd,
                           3:shared.StaleMembershipExceptionThrift sm,
                           4:InvalidSegmentUnitStatusExceptionThrift isus,
                           5:shared.InternalErrorThrift ie),

    // This API should be used internally, meaning not by coordinator. Most likely, it is used by testing.
    UpdateSegmentUnitMembershipAndStatusResponse updateSegmentUnitMembershipAndStatus(1:UpdateSegmentUnitMembershipAndStatusRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.StaleMembershipExceptionThrift sm,
                           3:shared.InvalidMembershipExceptionThrift ime,
                           4:InvalidSegmentUnitStatusExceptionThrift isus,
                           5:shared.NotPrimaryExceptionThrift npe,
                           6:shared.InternalErrorThrift ie),

    // This API is used to update volume metadata that is stored in the segment unit metadata
    UpdateSegmentUnitVolumeMetadataJsonResponse updateSegmentUnitVolumeMetadataJson(1:UpdateSegmentUnitVolumeMetadataJsonRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.StaleMembershipExceptionThrift sm,
                           3:shared.InvalidMembershipExceptionThrift ime,
                           4:shared.InternalErrorThrift ie),

    // The moderator kicks of the potential primary so that the potential primary can start to sync its logs and build up a group.
    KickOffPotentialPrimaryResponse kickoffPrimary(1:KickOffPotentialPrimaryRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.InvalidMembershipExceptionThrift ime,
                           3:shared.NotPrimaryExceptionThrift npe,
                           4:shared.ServiceHavingBeenShutdownThrift shbsd,
                           5:InvalidSegmentUnitStatusExceptionThrift isus,
                           6:shared.InternalErrorThrift ie),

    MakePrimaryDecisionResponse makePrimaryDecision(1:MakePrimaryDecisionRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.InvalidMembershipExceptionThrift ime,
                           3:shared.NotPrimaryExceptionThrift npe,
                           4:shared.ServiceHavingBeenShutdownThrift shbsd,
                           5:InvalidSegmentUnitStatusExceptionThrift isus,
                           6:FailedToKickOffPrimaryExceptionThrift ftkop,
                           7:NoAvailableCandidatesForNewPrimaryExceptionThrift nacfnp,
                           8:shared.InternalErrorThrift ie),
   
    // Join a group. The request must be sent to the group primary. Otherwise NotPrimaryExceptionThrift is thrown
    // If the primary agrees to take the sender as a member, but finds out it has a stale membership,
    // the primary still sends ok back with the latest membership information
    JoiningGroupResponse canJoinGroup(1:JoiningGroupRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:JoiningGroupRequestDeniedExceptionThrift jgr,
                           3:shared.NotPrimaryExceptionThrift sm,
                           4:shared.InvalidMembershipExceptionThrift ime,
                           5:shared.ServiceHavingBeenShutdownThrift shbsd,
                           6:shared.InternalErrorThrift ie),

    BroadcastResponse broadcast(1:BroadcastRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                           2:shared.StaleMembershipExceptionThrift sm, 
                           3:shared.ChecksumMismatchedExceptionThrift cm,
                           4:shared.PrimaryExistsExceptionThrift pe,
                           5:shared.LogIdTooSmallExceptionThrift lts,
                           6:shared.LeaseExpiredExceptionThrift lee,
                           7:shared.NotPrimaryExceptionThrift npet,
                           8:shared.InvalidParameterValueExceptionThrift ipve,
                           9:InvalidTokenThrift it, 
                           10:InvalidSegmentUnitStatusExceptionThrift isus,
                           11:shared.InvalidMembershipExceptionThrift ime,
                           12:shared.ReceiverStaleMembershipExceptionThrift rsmse,
                           13:shared.ServiceHavingBeenShutdownThrift shbsd,
                           14:InputHasNoDataExceptionThrift ihnd, 
                           15:InappropriateLogStatusExceptionThrift ials, 
                           16:LeaseExtensionFrozenExceptionThrift lefe, 
                           17:shared.SegmentUnitBeingDeletedExceptionThrift subde, 
                           18:shared.ResourceExhaustedExceptionThrift ree, 
                           19:shared.InternalErrorThrift ie,
                           20:WriteMutationLogExceptionThrift wme,
                           21:AbortMutationLogExceptionThrift ame,
                           22:shared.NotSecondaryExceptionThrift nse,
                           24:shared.TimeoutExceptionThrift te),

    shared.OnlineDiskResponse onlineDisk(1:shared.OnlineDiskRequest request) throws (1:shared.DiskNotFoundExceptionThrift snf,
                           2:shared.DiskHasBeenOnlineThrift npm,
                           3:shared.ServiceHavingBeenShutdownThrift shbsd,
                           4:shared.InternalErrorThrift ie),

    shared.OfflineDiskResponse offlineDisk(1:shared.OfflineDiskRequest request) throws (1:shared.DiskNotFoundExceptionThrift snf,
                           2:shared.DiskHasBeenOfflineThrift npm,
                           3:shared.ServiceHavingBeenShutdownThrift shbsd,
                           4:shared.InternalErrorThrift ie,
                           5:shared.DiskIsBusyThrift dibe),

    shared.DegradeDiskResponse degradeDisk(1:shared.DegradeDiskRequest request),

    shared.OnlineDiskResponse fixBrokenDisk(1:shared.OnlineDiskRequest request) throws (1:shared.DiskNotFoundExceptionThrift snf,
                           2:shared.DiskNotBrokenThrift dnbe,
                           3:shared.ServiceHavingBeenShutdownThrift shbsd,
                           4:shared.InternalErrorThrift ie),

    shared.OnlineDiskResponse fixConfigMismatchedDisk(1:shared.OnlineDiskRequest request) throws (1:shared.DiskNotFoundExceptionThrift snf,
                           2:shared.DiskNotMismatchConfigThrift dnme,
                           3:shared.ServiceHavingBeenShutdownThrift shbsd,
                           4:shared.InternalErrorThrift ie),

    shared.GetLatestLogsResponseThrift getLatestLogsFromPrimary(1:shared.GetLatestLogsRequestThrift request) throws (1:shared.InternalErrorThrift ie,
                           2:SegmentNotFoundExceptionThrift snfe,
                           3:shared.NotPrimaryExceptionThrift npe),

    shared.CommitLogsResponseThrift commitLog(1:shared.CommitLogsRequestThrift request) throws(1:shared.InternalErrorThrift ie,
                           2:SegmentNotFoundExceptionThrift snfe,
                           3:shared.InvalidMembershipExceptionThrift ime,
                           4:shared.StaleMembershipExceptionThrift sme,
                           5:shared.NotPrimaryExceptionThrift npe,
                           6:shared.NotSecondaryExceptionThrift nse),

    shared.ConfirmAbortLogsResponseThrift confirmAbortLog(1:shared.ConfirmAbortLogsRequestThrift request) throws(1:shared.InternalErrorThrift ie,
                           2:SegmentNotFoundExceptionThrift snfe,
                           3:shared.NotPrimaryExceptionThrift npe),

    HeartbeatResponse heartbeat(1:HeartbeatRequest request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd),

    shared.RemoveUncommittedLogsExceptForThoseGivenResponse removeUncommittedLogsExceptForThoseGiven(1:shared.RemoveUncommittedLogsExceptForThoseGivenRequest request) throws (1:SegmentNotFoundExceptionThrift snf),

    shared.SetDatanodeDomainResponseThrift setDatanodeDomain(1:shared.SetDatanodeDomainRequestThrift request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd,
                           2:shared.InvalidInputExceptionThrift iie,
                           3:shared.DatanodeIsUsingExceptionThrift diue),

    shared.FreeDatanodeDomainResponseThrift freeDatanodeDomain(1:shared.FreeDatanodeDomainRequestThrift request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd,
                           2:shared.InvalidInputExceptionThrift iie),

    shared.SetArchiveStoragePoolResponseThrift setArchiveStoragePool(1:shared.SetArchiveStoragePoolRequestThrift request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd,
                           2:shared.InvalidInputExceptionThrift iie,
                           3:shared.ArchiveIsUsingExceptionThrift aiue),

    shared.FreeArchiveStoragePoolResponseThrift freeArchiveStoragePool(1:shared.FreeArchiveStoragePoolRequestThrift request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd,
                           2:shared.InvalidInputExceptionThrift iie),

    StartOnlineMigrationResponse startOnlineMigration(1:StartOnlineMigrationRequest request) throws(1:shared.ServiceHavingBeenShutdownThrift shbsd,
                           2:InitializeBitmapExceptionThrift ibe,
                           3:shared.ConnectionRefusedExceptionThrift cre,
                           4:shared.SegmentExistingExceptionThrift see,),


    //=================== Please DON'T Add APIs to the following zone ================
    //=================== The following APIs is for debugging purpose Only ================
    shared.SetIoErrorResponse setIoError(1:shared.SetIoErrorRequest request) throws (1:shared.DiskNotFoundExceptionThrift snf,
                           2:shared.ServiceHavingBeenShutdownThrift shbsd,
                           3:shared.InternalErrorThrift ie),

    shared.SetArchiveConfigResponse setArchiveConfig(1:shared.SetArchiveConfigRequest request) throws (1:shared.DiskNotFoundExceptionThrift snf,
                           2:shared.ServiceHavingBeenShutdownThrift shbsd,
                           3:shared.InternalErrorThrift ie),

    InvalidateCacheResponse invalidateCache(1:InvalidateCacheRequest request) throws (1:NotSupportedExceptionThrift nse),

    ReleaseAllLogsResponse releaseAllLogs(1:ReleaseAllLogsRequest request),

    shared.HeartbeatDisableResponse heartbeatDisable(1:shared.HeartbeatDisableRequest request) throws (1:SegmentNotFoundExceptionThrift snf),

    shared.WriteMutationLogsDisableResponse writeMutationLogDisable(2:shared.WriteMutationLogsDisableRequest request) throws (1:SegmentNotFoundExceptionThrift snf),

    shared.GetDbInfoResponseThrift getDbInfo(1:shared.GetDbInfoRequestThrift request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd),

    RetrieveBitMapResponse retrieveBitMap(1:RetrieveBitMapRequest request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd,
                           2:SegmentNotFoundExceptionThrift snf,
                           3:OnSameArchiveExceptionThrift osae,
                           4:shared.InternalErrorThrift ie),

    BackupDatabaseInfoResponse backupDatabaseInfo(1:BackupDatabaseInfoRequest request) throws (
                                                                            1:shared.ServiceHavingBeenShutdownThrift shbsd),

    MigratePrimaryResponse migratePrimary(1:MigratePrimaryRequest request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd,
                           2:SegmentNotFoundExceptionThrift snf,
                           3:shared.PrimaryCandidateCantBePrimaryExceptionThrift pccbpe,
                           4:shared.SegmentUnitCloningExceptionThrift suce,
                           5:shared.ArchiveNotFoundExceptionThrift anfe,
                           6:shared.SnapshotRollingBackExceptionThrift srbe,
                           7:shared.NotEnoughSpaceExceptionThrift nese,
                           8:shared.InternalErrorThrift ie),

    InnerMigrateSegmentUnitResponse innerMigrateSegmentUnit(1:InnerMigrateSegmentUnitRequest request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd,
                           2:SegmentNotFoundExceptionThrift snf,
                           3:shared.InternalErrorThrift ie),

    ImReadyToBePrimaryResponse iAmReadyToBePrimary(1:ImReadyToBePrimaryRequest request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd,
                           2:SegmentNotFoundExceptionThrift snf,
                           3:shared.YouAreNotInRightPositionExceptionThrift yanirpe,
                           4:shared.YouAreNotReadyExceptionThrift yanre,
                           5:shared.InternalErrorThrift ie),

    CanYouBecomePrimaryResponse canYouBecomePrimary(1:CanYouBecomePrimaryRequest request) throws (1:shared.ServiceHavingBeenShutdownThrift shbsd,
                           2:SegmentNotFoundExceptionThrift snf,
                           3:shared.InternalErrorThrift ie),

    shared.SettleArchiveTypeResponse settleArchiveType( 1:shared.SettleArchiveTypeRequest request) throws (1:shared.DiskNotFoundExceptionThrift dnfe,
                                                                                                          2:shared.DiskSizeCanNotSupportArchiveTypesThrift ds,
                                                                                                          3:shared.ServiceHavingBeenShutdownThrift shbsd,
                                                                                                          4:shared.ArchiveManagerNotSupportExceptionThrift atn,
                                                                                                          5:shared.InternalErrorThrift ie),

    DepartFromMembershipRespone departFromMembership(   1:DepartFromMembershipRequest request) throws (1:SegmentNotFoundExceptionThrift snf,
                                                        2:RefuseDepartFromMembershipExceptionThrift rdf,
                                                        3:shared.ServiceHavingBeenShutdownThrift sgb,
                                                        4:shared.ConnectionRefusedExceptionThrift cre),

    shared.ForceUpdateMembershipResponse forceUpdateMembership(1:shared.ForceUpdateMembershipRequest request)
                                         throws (1:shared.ServiceHavingBeenShutdownThrift sgb,
                                                 2:shared.ConnectionRefusedExceptionThrift cre),

    CheckSecondaryHasAllLogResponse checkSecondaryHasAllLog(1:CheckSecondaryHasAllLogRequest request)
                                             throws (1:shared.ServiceHavingBeenShutdownThrift sgb,
                                                     2:shared.ConnectionRefusedExceptionThrift cre),


}

