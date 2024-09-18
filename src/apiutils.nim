# SPDX-License-Identifier: AGPL-3.0-only
import httpclient, asyncdispatch, options, strutils, uri, times, tables
import packedjson, zippy
import types, auth, consts, parserutils, http_pool
import experimental/types/common
import config

const
  rlRemaining = "x-rate-limit-remaining"
  rlReset = "x-rate-limit-reset"

var pool: HttpPool

proc genParams*(pars: openArray[(string, string)] = @[]; cursor="";
                count="20"; ext=true): seq[(string, string)] =
  result = timelineParams
  for p in pars:
    result &= p
  if ext:
    result &= ("include_ext_alt_text", "1")
    result &= ("include_ext_media_stats", "1")
    result &= ("include_ext_media_availability", "1")
  if count.len > 0:
    result &= ("count", count)
  if cursor.len > 0:
    # The raw cursor often has plus signs, which sometimes get turned into spaces,
    # so we need to turn them back into a plus
    if " " in cursor:
      result &= ("cursor", cursor.replace(" ", "+"))
    else:
      result &= ("cursor", cursor)

proc genHeaders*(url: string): HttpHeaders =
  
  result = newHttpHeaders({
    "connection": "close",
    "authorization": bearerToken,
    "Cookie": cfg.cookieHeader,
    "x-csrf-token": cfg.xCsrfToken,
    "content-type": "application/json",
    "x-twitter-active-user": "yes",
    "authority": "api.twitter.com",
    "accept-encoding": "gzip",
    "accept-language": "en-US,en;q=0.9",
    "accept": "*/*",
    "DNT": "1"
  })
  
template updateAccount() =
  if resp.headers.hasKey(rlRemaining):
    let
      remaining = parseInt(resp.headers[rlRemaining])
      reset = parseInt(resp.headers[rlReset])
    account.setRateLimit(api, remaining, reset)

template fetchImpl(result, additional_headers, fetchBody) {.dirty.} =
  once:
    pool = HttpPool()

  try:
    var resp: AsyncResponse
    var headers = genHeaders($url)
    for key, value in additional_headers.pairs():
      headers.add(key, value)
    pool.use(headers):
      template getContent =
        resp = await c.get($url)
        result = await resp.body

      getContent()

      if resp.status == $Http429:
        raise rateLimitError()

      if resp.status == $Http503:
        badClient = true
        raise newException(BadClientError, "Bad client")

    #if resp.headers.hasKey(rlRemaining):
    #  let
    #    remaining = parseInt(resp.headers[rlRemaining])
    #    reset = parseInt(resp.headers[rlReset])
    #  account.setRateLimit(api, remaining, reset)

    if result.len > 0:
      if resp.headers.getOrDefault("content-encoding") == "gzip":
        result = uncompress(result, dfGzip)

    fetchBody

    if resp.status == $Http400:
      raise newException(InternalError, $url)
  except InternalError as e:
    raise e
  except BadClientError as e:
    raise e
  except OSError as e:
    raise e

template retry(bod) =
  try:
    bod
  except RateLimitError:
    echo "[accounts] Rate limited, retrying ", api, " request..."
    bod

proc fetch*(url: Uri; api: Api; additional_headers: HttpHeaders = newHttpHeaders()): Future[JsonNode] {.async.} =
  retry:
    var body: string
    fetchImpl(body, additional_headers):
      if body.startsWith('{') or body.startsWith('['):
        result = parseJson(body)
      else:
        echo resp.status, ": ", body, " --- url: ", url
        result = newJNull()

      let error = result.getError
      if error in {expiredToken, badToken}:
        echo "fetchBody error: ", error
        #invalidate(account)
        raise rateLimitError()

proc fetchRaw*(url: Uri; api: Api; additional_headers: HttpHeaders = newHttpHeaders()): Future[string] {.async.} =
  retry:
    fetchImpl(result, additional_headers):
      if not (result.startsWith('{') or result.startsWith('[')):
        echo resp.status, ": ", result, " --- url: ", url
        result.setLen(0)
