# activestorage-ve-tos

ActiveStorage adapter for [Volcengine TOS](https://www.volcengine.com/docs/6349). Wraps ve-tos-ruby-sdk.

## Installation

```ruby
# Gemfile
gem "activestorage-ve-tos"
```

Then execute:

```
bundle install
```

## Configuration

```yaml
# config/storage.yml
ve_tos:
  service: VeTos
  access_key_id: <%= ENV["TOS_ACCESS_KEY_ID"] %>
  secret_access_key: <%= ENV["TOS_SECRET_ACCESS_KEY"] %>
  region: cn-beijing
  bucket: my-bucket
  # endpoint: tos-cn-beijing.volces.com   # default: tos-{region}.volces.com
  # public: false                          # if true and `host` is set, url returns an unsigned CDN url
  # host: cdn.example.com                  # custom domain for delivery (replaces TOS host)
  # upload_host: my-bucket.tos-cn-beijing.volces.com  # for direct uploads
  # prefix: production                     # all keys are prefixed with this
```

Then point your environment at the new service in `config/environments/*.rb`:

```ruby
config.active_storage.service = :ve_tos
```

## Direct uploads

`url_for_direct_upload` returns a presigned PUT URL. Configure CORS on your TOS bucket to allow `PUT` from your origin and the headers `Content-Type`, `Content-MD5`, `x-tos-meta-*`.

## What it does

| ActiveStorage method    | Backed by                                                                      |
| ----------------------- | ------------------------------------------------------------------------------ |
| `upload`                | `PutObject`                                                                    |
| `download` (full)       | `GetObject`                                                                    |
| `download` (with block) | `GetObject` (streaming)                                                        |
| `download_chunk`        | `GetObject` with `Range`                                                       |
| `delete`                | `DeleteObject` (404 swallowed)                                                 |
| `delete_prefixed`       | `ListObjectsV2` + `DeleteMultipleObjects` (paginated)                          |
| `exist?`                | `HeadObject`                                                                   |
| `url`                   | Presigned GET, or `https://{host}/{key}` when `public: true` and `host` is set |
| `url_for_direct_upload` | Presigned PUT                                                                  |
| `compose`               | Streamed concatenation + re-upload                                             |

## Caveats

- `compose` reads sources fully into memory and re-uploads. Fine for variants/thumbnails, not for very large composites.
- Multipart upload is not supported by the underlying SDK yet, so `upload` sends the whole body in a single PutObject. Volcengine's per-request limit applies.

## Development

```
bundle install
bundle exec rspec
```

## License

MIT
