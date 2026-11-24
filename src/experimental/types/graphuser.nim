import options, strutils
from ../../types import User, VerifiedType
import common
import user as userType  # Entities, for modern profile_bio parsing

type
  GraphUser* = object
    data*: tuple[userResult: Option[UserData], user: Option[UserData]]

  UserData* = object
    result*: UserResult

  UserCore* = object
    name*: string
    screenName*: string
    createdAt*: string

  UserBio* = object
    description*: string
    entities*: Entities

  GrokBioEntities* = object
    urls*: seq[Url]

  GrokBioData* = object
    translation*: string
    sourceLanguage*: string
    entities*: GrokBioEntities

  GrokBio* = object
    isAvailable*: Option[bool]
    data*: Option[GrokBioData]

  UserAvatar* = object
    imageUrl*: string

  Verification* = object
    verifiedType*: VerifiedType

  Location* = object
    location*: string

  Privacy* = object
    protected*: bool

  # Modern UserByRestId/UserByScreenName shape moves the counts out of `legacy`
  # into these typed sub-objects.
  RelationshipCounts* = object
    followers*: int
    following*: int

  TweetCounts* = object
    tweets*: int
    mediaTweets*: int

  ActionCounts* = object
    favoritesCount*: int

  UserResult* = object
    legacy*: User
    restId*: string
    isBlueVerified*: bool
    parodyCommentaryFanLabel*: string
    core*: UserCore
    avatar*: UserAvatar
    banner*: UserAvatar
    unavailableReason*: Option[string]
    reason*: Option[string]
    privacy*: Option[Privacy]
    profileBio*: Option[UserBio]
    verification*: Option[Verification]
    location*: Option[Location]
    relationshipCounts*: Option[RelationshipCounts]
    tweetCounts*: Option[TweetCounts]
    actionCounts*: Option[ActionCounts]
    isProfileTranslatable*: bool
    grokTranslatedBioWithAvailability*: Option[GrokBio]

proc enumHook*(s: string; v: var VerifiedType) =
  v = try:
    parseEnum[VerifiedType](s)
  except:
    VerifiedType.none
