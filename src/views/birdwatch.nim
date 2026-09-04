# SPDX-License-Identifier: AGPL-3.0-only
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
    tdiv(class="community-note-text", dir="auto"):
      verbatim replaceUrls(linkifyUrls(note.text), prefs)

proc renderBirdwatchNotes*(tweet: Tweet; notes: BirdwatchNotes; prefs: Prefs;
                           path: string): VNode =
  buildHtml(tdiv(class="timeline-container birdwatch-notes")):
    if tweet != nil and tweet.id != 0:
      renderTweet(tweet, prefs, path, mainTweet=true)

    tdiv(class="timeline-header"):
      text "Community Notes"
    if notes.notes.len == 0:
      tdiv(class="timeline-none"):
        text "No community notes found for this post."
    else:
      for note in notes.notes:
        renderBirdwatchNote(note, prefs)
