# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, sequtils, uri, options, sugar

import jester, karax/vdom

import router_utils
import ".."/[types, formatters, api, apiutils]
import ../views/[general, status, search, timeline, birdwatch]

export uri, sequtils, options, sugar
export router_utils
export api, formatters
export status
export birdwatch

proc createStatusRouter*(cfg: Config) =
  router status:
    get "/@name/status/@id/?":
      cond '.' notin @"name"
      let id = @"id"

      if id.len > 19 or id.any(c => not c.isDigit):
        resp Http404, showError("Invalid tweet ID", cfg)

      let
        prefs = requestPrefs()
        sort = parseEnum[RankingMode](@"sort".toLowerAscii.capitalizeAscii, Relevance)

      # used for the infinite scroll feature
      if @"scroll".len > 0:
        let replies = await getReplies(id, getCursor(), sort)
        if replies.content.len == 0:
          resp Http204
        resp $renderReplies(replies, prefs, getPath(), sort=sort)

      let conv = await getTweet(id, getCursor(), sort)

      if conv == nil or conv.tweet == nil or conv.tweet.id == 0:
        var error = "Tweet not found"
        if conv != nil and conv.tweet != nil and conv.tweet.tombstone.len > 0:
          error = conv.tweet.tombstone
        resp Http404, showError(error, cfg)

      let
        title = pageTitle(conv.tweet)
        ogTitle = pageTitle(conv.tweet.user)
        desc = conv.tweet.text

      var
        images = conv.tweet.getPhotos.mapIt(it.url)
        video = ""

      let
        firstMediaKind = if conv.tweet.media.len > 0: conv.tweet.media[0].kind
                         else: photoMedia

      if firstMediaKind == videoMedia:
        images = @[conv.tweet.media[0].getThumb]
        video = getVideoEmbed(cfg, conv.tweet.id)
      elif firstMediaKind == gifMedia:
        images = @[conv.tweet.media[0].getThumb]
        video = getPicUrl(conv.tweet.media[0].gif.url)
      elif conv.tweet.card.isSome():
        let card = conv.tweet.card.get()
        if card.image.len > 0:
          images = @[card.image]
        elif card.video.isSome():
          images = @[card.video.get().thumb]

      let
        tweetUrl = getUrlPrefix(cfg) & "/" & conv.tweet.user.username & "/status/" & $conv.tweet.id
        oembedUrl = getUrlPrefix(cfg) & "/api/oembed?url=" & encodeUrl(tweetUrl)

      let html = renderConversation(conv, prefs, getPath() & "#m", sort)
      resp renderMain(html, request, cfg, prefs, title, desc, ogTitle,
                      images=images, video=video, oembed=oembedUrl)

    get "/@name/status/@id/history/?":
      cond '.' notin @"name"
      let id = @"id"

      if id.len > 19 or id.any(c => not c.isDigit):
        resp Http404, showError("Invalid tweet ID", cfg)

      let edits = await getGraphEditHistory(id)
      if edits.latest == nil or edits.latest.id == 0:
        resp Http404, showError("Tweet history not found", cfg)

      let
        prefs = requestPrefs()
        title = "History for " & pageTitle(edits.latest)
        ogTitle = "Edit History for " & pageTitle(edits.latest.user)
        desc = edits.latest.text

      let html = renderEditHistory(edits, prefs, getPath())
      resp renderMain(html, request, cfg, prefs, title, desc, ogTitle)

    get "/@name/status/@id/@tab/?":
      cond '.' notin @"name"
      cond @"tab" in ["retweets", "quotes"]
      let
        id = @"id"
        name = @"name"
        tab = @"tab"

      if id.len > 19 or id.any(c => not c.isDigit):
        resp Http404, showError("Invalid tweet ID", cfg)

      let prefs = requestPrefs()

      if tab == "retweets":
        if isGuestAuth():
          if @"scroll".len > 0:
            resp Http204
          resp renderMain(renderRetweetersUnavailable(name, id), request, cfg, prefs,
                           "Retweets", "Retweets of this post", "Retweets")

        let results = await getGraphRetweeters(id, getCursor())
        if @"scroll".len > 0:
          if results.content.len == 0:
            resp Http204
          resp $renderTimelineUsers(results, prefs)
        resp renderMain(renderRetweeters(results, prefs, name, id), request, cfg, prefs,
                         "Retweets", "Retweets of this post", "Retweets")
      else:
        let query = Query(kind: posts, text: "-filter:retweets quoted_tweet_id:" & id)
        let results = await getGraphTweetSearch(query, getCursor())
        if @"scroll".len > 0:
          if results.content.len == 0:
            resp Http204
          resp $renderTimelineTweets(results, prefs, getPath(), none(Tweet))
        resp renderMain(renderQuotes(results, prefs, getPath(), name, id), request, cfg, prefs,
                         "Quoted Tweets", "Tweets quoting this post", "Quoted Tweets")

    get "/i/birdwatch/t/@id":
      let id = @"id"

      if id.len > 19 or id.any(c => not c.isDigit):
        resp Http404, showError("Invalid tweet ID", cfg)

      let
        prefs = requestPrefs()
        conv = await getTweet(id)
        notes = await getGraphBirdwatchNotes(id)
        tweet = if conv != nil: conv.tweet else: nil

      resp renderMain(renderBirdwatchNotes(tweet, notes, prefs, getPath()), request, cfg, prefs,
                       "Community Notes", "Community notes for this post", "Community Notes")

    get "/@name/@s/@id/@m/?@i?":
      cond @"s" in ["status", "statuses"]
      cond @"m" in ["video", "photo"]
      redirect("/$1/status/$2" % [@"name", @"id"])

    get "/@name/statuses/@id/?":
      redirect("/$1/status/$2" % [@"name", @"id"])

    get "/i/web/status/@id":
      redirect("/i/status/" & @"id")

    get "/@name/thread/@id/?":
      redirect("/$1/status/$2" % [@"name", @"id"])
