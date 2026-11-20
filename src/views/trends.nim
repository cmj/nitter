# SPDX-License-Identifier: AGPL-3.0-only
import strformat, strutils, uri
import karax/[karaxdsl, vdom]

import ../trends, ../types
import trending

proc renderTrendsList(trends: seq[Trend]): VNode =
  buildHtml(ul(class="trends-list")):
    if trends.len == 0:
      li(class="trends-empty"): text "No trends available right now."
    else:
      for t in trends:
        li(class="trend-item"):
          a(href=("/search?q=" & encodeUrl(t.searchQuery))):
            span(class="trend-name"): text t.name
            if t.tweetVolume >= 0:
              span(class="trend-volume"): text insertSep($t.tweetVolume, ',') & " tweets"

proc renderTrendsTabs*(tab1Name: string, tab1: seq[Trend],
                       tab2Name: string, tab2: seq[Trend]): VNode =
  buildHtml(tdiv(class="trends-panel")):
    input(`type`="radio", name="trends-tab", id="trends-tab-1",
          class="trends-tab-radio", checked="checked")
    input(`type`="radio", name="trends-tab", id="trends-tab-2",
          class="trends-tab-radio")

    tdiv(class="trends-tab-labels"):
      label(`for`="trends-tab-1", class="trends-tab-label"): text tab1Name
      label(`for`="trends-tab-2", class="trends-tab-label"): text tab2Name

    tdiv(class="trends-tab-panel", id="trends-panel-1"):
      renderTrendsList(tab1)
    tdiv(class="trends-tab-panel", id="trends-panel-2"):
      renderTrendsList(tab2)

proc renderTrendRows(trends: seq[Trend]): VNode =
  buildHtml(tdiv(class="timeline")):
    if trends.len == 0:
      tdiv(class="timeline-none"): text "No trends available right now."
    else:
      for t in trends:
        tdiv(class="timeline-item trend-row"):
          a(href=("/search?q=" & encodeUrl(t.searchQuery))):
            span(class="trend-name"): text t.name
            if t.tweetVolume >= 0:
              span(class="trend-volume"): text insertSep($t.tweetVolume, ',') & " tweets"

proc renderTrendsPageTabs(active, tab1Name, tab2Name: string): VNode =
  func cls(tab: string): string =
    if active == tab: "tab-item active" else: "tab-item"
  buildHtml(ul(class="tab")):
    li(class=cls("1")):
      a(href="/i/trends"): text tab1Name
    li(class=cls("2")):
      a(href="/i/trends?tab=2"): text tab2Name
    li(class=cls("news")):
      a(href="/i/trends?tab=news"): text "News"

proc renderStorySort(sort: StorySort): VNode =
  buildHtml(tdiv(class="reply-sort story-sort")):
    span(class="reply-sort-label"): text "Sort:"
    for mode in StorySort:
      let
        cls = if mode == sort: "reply-sort-option active"
              else: "reply-sort-option"
        href = if mode == Relevant: "/i/trends?tab=news"
               else: "/i/trends?tab=news&sort=" & toLowerAscii($mode)
      a(class=cls, href=href):
        text $mode

proc renderTrendsPage*(active, tab1Name, tab2Name: string;
                       trends: seq[Trend]; stories: StoryPage;
                       sort = Relevant): VNode =
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      text "Trends"
    renderTrendsPageTabs(active, tab1Name, tab2Name)
    if active == "news":
      renderStorySort(sort)
      renderStoryList(stories, "/i/trends?tab=news&", news=true)
    else:
      renderTrendRows(trends)

proc renderHomeBody*(tab1Name: string, tab1: seq[Trend],
                     tab2Name: string, tab2: seq[Trend]; search: VNode): VNode =
  buildHtml(tdiv(class="home-panel")):
    search
    renderTrendsTabs(tab1Name, tab1, tab2Name, tab2)
