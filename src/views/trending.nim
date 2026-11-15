# SPDX-License-Identifier: AGPL-3.0-only
import strutils, times, uri
import karax/[karaxdsl, vdom]

import timeline
import ".."/[types, formatters]

proc timeAgo(ms: int64): string =
  let secs = max(0'i64, getTime().toUnix - ms div 1000)
  proc plural(n: int64; unit: string): string =
    $n & " " & unit & (if n == 1: "" else: "s") & " ago"
  if secs < 60: "just now"
  elif secs < 3600: plural(secs div 60, "minute")
  elif secs < 86400: plural(secs div 3600, "hour")
  else: plural(secs div 86400, "day")

proc tabHref(id, timelineId: string; first: bool): string =
  if first: "/i/trending/" & id
  else: "/i/trending/" & id & "?timeline=" & encodeUrl(timelineId, usePlus=false)

proc renderTrendingTabs*(id: string; tabs: seq[StoryTimeline];
                         active: string): VNode =
  buildHtml(ul(class="tab")):
    for i, t in tabs:
      li(class=(if t.id == active: "tab-item active" else: "tab-item")):
        a(href=tabHref(id, t.id, i == 0)): text t.label

proc renderStoryHeader*(s: StoryDetail): VNode =
  buildHtml(tdiv(class="story-detail")):
    if s.title.len > 0:
      h1(class="story-detail-title"): text s.title
    if s.updatedMs > 0:
      tdiv(class="story-detail-updated"):
        text "Last updated " & timeAgo(s.updatedMs)
    if s.summary.len > 0:
      tdiv(class="story-detail-summary"): text s.summary

proc renderTrending*(id: string; detail: StoryDetail; tabs: seq[StoryTimeline];
                     active: string; tl: Timeline; prefs: Prefs;
                     path: string): VNode =
  let extra =
    if tabs.len > 0 and active != tabs[0].id:
      "timeline=" & encodeUrl(active, usePlus=false) & "&"
    else: ""
  buildHtml(tdiv(class="timeline-container")):
    if detail.title.len > 0 or detail.summary.len > 0:
      renderStoryHeader(detail)
    renderTrendingTabs(id, tabs, active)
    renderTimelineTweets(tl, prefs, path, extra=extra)

proc renderStoryList*(page: StoryPage; moreBase: string; news = false): VNode =
  let cls = if news: "stories-list stories-news timeline" else: "stories-list timeline"
  buildHtml(tdiv(class=cls)):
    if page.stories.len == 0:
      tdiv(class="stories-empty"):
        text "No stories available right now. This endpoint needs an authenticated session."
    else:
      for s in page.stories:
        tdiv(class="story-item"):
          a(href=("/i/trending/" & s.id)):
            tdiv(class="story-meta"):
              span(class="story-category"): text s.category
              span(class="story-count"): text insertSep(s.postCount, ',') & (if news: " tweets" else: " posts")
              span(class="story-date"):
                text getShortTime(fromUnix(s.createdMs div 1000).utc)
            tdiv(class="story-title"): text s.name
            if s.hook.len > 0:
              tdiv(class="story-hook"): text s.hook
      if page.bottom.len > 0:
        tdiv(class="show-more"):
          a(href=(moreBase & "cursor=" & encodeUrl(page.bottom, usePlus=false))):
            text "Load more"
      renderToTop()

proc renderStories*(page: StoryPage): VNode =
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="stories-header"): text "Trending"
    renderStoryList(page, "/i/trending/?")
