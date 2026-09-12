# SPDX-License-Identifier: AGPL-3.0-only
import times, sequtils, uri
import karax/[karaxdsl, vdom]

import renderutils, tweet
import ".."/[types, formatters]

proc renderBirdwatchNote(note: BirdwatchNote; prefs: Prefs): VNode =
  var label = if note.helpful: "Community Note" else: "Proposed Community Note"
  label &= (if note.misleading: " - Misleading" else: " - Not Misleading")
  var cls = "community-note"
  if not note.helpful: cls &= " proposed"
  cls &= (if note.misleading: " misleading" else: " not-misleading")
  buildHtml(tdiv(class=cls)):
    tdiv(class="community-note-header"):
      icon "group"
      span: text label
      if note.id.len > 0:
        a(class="community-note-permalink", href="/i/birdwatch/n/" & note.id, title="Permalink to this note"):
          icon "link"
    tdiv(class="community-note-text", dir="auto"):
      verbatim linkifyBirdwatchUrls(note.text)
    tdiv(class="community-note-meta-sep")
    tdiv(class="community-note-meta"):
      if note.authorAlias.len > 0:
        span(class="community-note-meta-item community-note-author"):
          text "By "
          a(href="/i/communitynotes/u/" & note.authorAlias):
            text note.authorAlias
      if note.createdAt.year > 0:
        span(class="community-note-meta-item community-note-date"):
          text note.createdAt.format("MMM d', 'yyyy' · 'h:mm tt' UTC'")
      # if note.classification.len > 0:
      #   span(class="community-note-meta-item"):
      #     text note.classification
      # if note.misleadingTags.len > 0:
      #   span(class="community-note-meta-item"):
      #     text "Misleading: " & note.misleadingTags.join(", ")
      # if note.helpfulTags.len > 0:
      #   span(class="community-note-meta-item"):
      #     text "Helpful: " & note.helpfulTags.join(", ")
      # if note.decidedBy.len > 0:
      #   span(class="community-note-meta-item"):
      #     text "Decided by " & note.decidedBy

proc renderBirdwatchHistoryNote(note: BirdwatchHistoryNote): VNode =
  var cls = "community-note"
  if not note.helpful: cls &= " proposed"
  buildHtml(tdiv(class=cls)):
    tdiv(class="community-note-header"):
      icon "group"
      span: text (if note.helpful: "Community Note" else: "Proposed Community Note")
      if note.id.len > 0:
        a(class="community-note-permalink", href="/i/birdwatch/n/" & note.id, title="Permalink to this note"):
          icon "link"
    tdiv(class="community-note-text", dir="auto"):
      verbatim linkifyBirdwatchUrls(note.text)
    tdiv(class="community-note-meta-sep")
    tdiv(class="community-note-meta"):
      if note.tweetUsername.len > 0 and note.tweetId != 0:
        span(class="community-note-meta-item community-note-author"):
          text "On "
          a(href="/" & note.tweetUsername & "/status/" & $note.tweetId):
            text "@" & note.tweetUsername & "'s post"
      if note.createdAt.year > 0:
        span(class="community-note-meta-item community-note-date"):
          text note.createdAt.format("MMM d', 'yyyy' · 'h:mm tt' UTC'")

proc renderBirdwatchHistoryContent*(history: BirdwatchHistory): VNode =
  buildHtml(tdiv(class="birdwatch-notes-list timeline")):
    if history.notes.allIt(it.text.len == 0):
      tdiv(class="timeline-none"):
        text "No notes found for this contributor."
    else:
      for note in history.notes:
        if note.text.len > 0:
          renderBirdwatchHistoryNote(note)

    if history.bottom.len > 0:
      tdiv(class="show-more"):
        a(href="?cursor=" & encodeUrl(history.bottom, usePlus=false)):
          text "Load more"

proc renderBirdwatchHistory*(history: BirdwatchHistory): VNode =
  buildHtml(tdiv(class="timeline-container birdwatch-notes")):
    tdiv(class="timeline-header"):
      text "Notes by " & history.alias
    renderBirdwatchHistoryContent(history)

proc renderBirdwatchSingleNote*(tweet: Tweet; note: BirdwatchNote; prefs: Prefs;
                                path: string): VNode =
  buildHtml(tdiv(class="timeline-container birdwatch-notes")):
    if tweet != nil and tweet.id != 0:
      renderTweet(tweet, prefs, path, mainTweet=true)

    tdiv(class="birdwatch-notes-list"):
      tdiv(class="timeline-header"):
        text "Community Note"

      if note.text.len > 0:
        renderBirdwatchNote(note, prefs)
      else:
        tdiv(class="timeline-none"):
          text "Note not found."

proc renderBirdwatchNotes*(tweet: Tweet; notes: BirdwatchNotes; prefs: Prefs;
                           path: string): VNode =
  buildHtml(tdiv(class="timeline-container birdwatch-notes")):
    if tweet != nil and tweet.id != 0:
      renderTweet(tweet, prefs, path, mainTweet=true)

    tdiv(class="birdwatch-notes-list"):
      tdiv(class="timeline-header"):
        text "Community Notes"

      if notes.notes.allIt(it.text.len == 0):
        tdiv(class="timeline-none"):
          text "No community notes found for this post."
      else:
        for note in notes.notes:
          if note.text.len > 0:
            renderBirdwatchNote(note, prefs)
