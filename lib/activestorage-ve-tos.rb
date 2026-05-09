# frozen_string_literal: true

require "active_storage"
require "tos"

require "activestorage_ve_tos/version"
require "active_storage/service/ve_tos_service"

# When `service: VeTos` is configured in `config/storage.yml`, ActiveStorage
# resolves it to `ActiveStorage::Service::VeTosService` via Ruby constant
# lookup — no extra wiring is needed.
module ActiveStorageVeTos
end
