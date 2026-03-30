require "net/http"
require "json"
require "uri"

module Solana
  class Client
    class RpcError < StandardError
      attr_reader :code
      def initialize(message, code: nil)
        @code = code
        super(message)
      end
    end

    MAX_RETRIES = 3
    RETRY_DELAY = 1 # seconds

    def initialize(rpc_url: Config::RPC_URL)
      @rpc_url = rpc_url
      @uri = URI.parse(rpc_url)
      @request_id = 0
    end

    def get_account_info(pubkey, encoding: "base64")
      call("getAccountInfo", [pubkey, { encoding: encoding }])
    end

    def get_token_account_balance(pubkey)
      call("getTokenAccountBalance", [pubkey])
    end

    def get_latest_blockhash(commitment: "finalized")
      result = call("getLatestBlockhash", [{ commitment: commitment }])
      result.dig("value", "blockhash")
    end

    def get_minimum_balance_for_rent_exemption(size)
      call("getMinimumBalanceForRentExemption", [size])
    end

    def send_transaction(signed_tx_base64, skip_preflight: false)
      opts = { encoding: "base64", skipPreflight: skip_preflight }
      call("sendTransaction", [signed_tx_base64, opts])
    end

    def confirm_transaction(signature, commitment: "confirmed")
      call("getSignatureStatuses", [[signature], { searchTransactionHistory: true }])
    end

    def send_and_confirm(signed_tx_base64, timeout: 30, skip_preflight: false)
      signature = send_transaction(signed_tx_base64, skip_preflight: skip_preflight)

      deadline = Time.now + timeout
      loop do
        sleep 1
        result = confirm_transaction(signature)
        status = result.dig("value", 0)

        if status
          if status["err"]
            raise RpcError.new("Transaction failed: #{status['err']}")
          end
          return signature if status["confirmationStatus"] == "confirmed" || status["confirmationStatus"] == "finalized"
        end

        raise RpcError.new("Transaction confirmation timeout") if Time.now > deadline
      end
    end

    def request_airdrop(pubkey, lamports)
      call("requestAirdrop", [pubkey, lamports])
    end

    def get_balance(pubkey)
      call("getBalance", [pubkey])
    end

    def get_token_accounts_by_owner(owner_pubkey)
      call("getTokenAccountsByOwner", [
        owner_pubkey,
        { programId: "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" },
        { encoding: "jsonParsed" }
      ])
    end

    private

    def call(method, params = [])
      @request_id += 1
      body = {
        jsonrpc: "2.0",
        id: @request_id,
        method: method,
        params: params
      }

      retries = 0
      begin
        response = http_post(body)
        parsed = JSON.parse(response.body)

        if parsed["error"]
          error = parsed["error"]
          raise RpcError.new(error["message"], code: error["code"])
        end

        parsed["result"]
      rescue RpcError => e
        # Retry on rate limit (429) or blockhash expiry
        if retries < MAX_RETRIES && retryable_error?(e)
          retries += 1
          sleep RETRY_DELAY * retries
          retry
        end
        raise
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET => e
        if retries < MAX_RETRIES
          retries += 1
          sleep RETRY_DELAY * retries
          retry
        end
        raise RpcError.new("Network error: #{e.message}")
      end
    end

    def http_post(body)
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = @uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(@uri.path.empty? ? "/" : @uri.path)
      request["Content-Type"] = "application/json"
      request.body = body.to_json

      http.request(request)
    end

    def retryable_error?(error)
      return true if error.code == 429 # rate limited
      return true if error.message.include?("Blockhash not found")
      false
    end
  end
end
