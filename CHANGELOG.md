# Changelog

## Added

- Quote count in the tweet stats row, linked to a new Quoted Tweets page (`/user/status/id/quotes`)
- New Retweets page (`/user/status/id/retweets`)
- Infinite scroll on both new pages
- New Community Notes page (`/i/birdwatch/t/<id>`) — misleading notes first, each labeled Community Note / Proposed Community Note with a Misleading / Not Misleading tag
- Community-notes indicator icon in the tweet stats row, linking to the notes page
- Client/app source label (iPhone, Android, Web App, etc.) in the tweet stats row, including on Articles
- Abbreviated stat count display option (`1.2M` vs `1,200,000`), per-user or admin-forced via config

## Fixed

- Reply sorting (Relevance/Recency/Likes) — now uses `TweetDetail`, which also restores per-reply source labels
- Missing `withBirdwatchNotes` request parameter causing the community-notes icon to not appear on UserTweets/SearchTimeline results
- Several missing/incorrect GraphQL request parameters silently dropping data (quote counts, view counts, source labels) on specific endpoints
