# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, sequtils, times, uri
import jester

import router_utils
import ".."/[types, api, utils, consts]
import ../views/[general, trending]

var
  storiesCache: StoryPage
  storiesFetched: Time
  storiesTtlMinutes = 1

proc getCachedStories*(minutes: int): Future[StoryPage] {.async.} =
  let now = getTime()
  if storiesFetched.toUnix > 0 and
     now - storiesFetched < initDuration(minutes = storiesTtlMinutes):
    return storiesCache

  var fresh: StoryPage
  try:
    fresh = await getStoriesPage()
  except CatchableError:
    discard

  storiesCache = fresh
  storiesFetched = now
  storiesTtlMinutes = if fresh.stories.len > 0: max(minutes, 1) else: 1
  return fresh

proc isTrendId*(id: string): bool =
  id.len > 0 and id.len <= 19 and id.allIt(it.isDigit)

proc storyTabs*(id: string; detail: StoryDetail): seq[StoryTimeline] =
  if detail.timelines.len > 0:
    return detail.timelines
  @[StoryTimeline(label: "Top",
                  id: encodeTrendingTimelineId(id, trendingTopFieldId)),
    StoryTimeline(label: "Latest",
                  id: encodeTrendingTimelineId(id, trendingLatestFieldId))]

proc trendingPage*(id: string; timeline, cursor: string; prefs: Prefs;
                   request: Request; cfg: Config): Future[string] {.async.} =
  var detail: StoryDetail
  try:
    detail = await getStoryDetail(id)
  except CatchableError:
    discard

  let
    tabs = storyTabs(id, detail)
    wanted = timeline.replace(' ', '+')
    active = if tabs.anyIt(it.id == wanted): wanted else: tabs[0].id
    tl = await getGraphTrending(id, timelineId=active, cursor=cursor)
    title = if detail.title.len > 0: detail.title else: "Trending"
    path = getPath()
  result = renderMain(renderTrending(id, detail, tabs, active, tl, prefs, path),
                      request, cfg, prefs, title, "Trending on X", "Trending")

proc trendingIndex*(cursor: string; prefs: Prefs; request: Request;
                    cfg: Config): Future[string] {.async.} =
  let page = await getStoriesPage(cursor)
  result = renderMain(renderStories(page), request, cfg, prefs,
                      "Trending", "Trending on X", "Trending")

proc createTrendingRouter*(cfg: Config) =
  router trending:
    get "/i/trending/?":
      if not cfg.enableTrends:
        resp Http404, showError("Trends are disabled", cfg)
      resp await trendingIndex(getCursor(), requestPrefs(), request, cfg)

    get "/i/trending/@id/?":
      cond isTrendId(@"id")
      if not cfg.enableTrends:
        resp Http404, showError("Trends are disabled", cfg)
      resp await trendingPage(@"id", @"timeline", getCursor(), requestPrefs(),
                              request, cfg)

    get "/i/trending/@id/new/?":
      cond isTrendId(@"id")
      if not cfg.enableTrends:
        resp Http404, showError("Trends are disabled", cfg)
      var detail: StoryDetail
      try:
        detail = await getStoryDetail(@"id")
      except CatchableError:
        discard
      let tabs = storyTabs(@"id", detail)
      redirect("/i/trending/" & @"id" & "?timeline=" &
               encodeUrl(tabs[^1].id, usePlus=false))
