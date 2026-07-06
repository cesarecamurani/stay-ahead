# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "bigdecimal"

USER_ID = ENV.fetch("SMOKE_TEST_USER_ID", "b3aa6236-86f8-48a9-84c1-2ce428cfc14f")
BASE = ENV.fetch("SMOKE_TEST_BASE_URL", "http://localhost:9000/api/v1")
class SmokeTest
  def initialize
    @user = User.find(USER_ID)
    @token = JwtService.encode(user_id: @user.id)
    @results = []
  end

  def run
    puts "Lifecycle smoke test — user #{@user.email} (#{USER_ID})"
    puts "Base URL: #{BASE}"
    puts "-" * 60

    section("1. Creation") { test_creation }
    section("2. Pause") { test_pause }
    section("3. Resume") { test_resume }
    section("4. Cancel") { test_cancel }
    section("5-7. Financial calculations") { test_financials }
    section("8. Validation") { test_validation }
    section("9. Authorization") { test_authorization }
    section("10. Edge cases") { test_edge_cases }

    print_summary
  end

  private

  def section(title)
    puts "\n## #{title}"
    yield
  end

  def record(name, pass, detail = nil)
    status = pass ? "PASS" : "FAIL"
    @results << { name:, pass:, detail: }
    line = "  [#{status}] #{name}"
    line += " — #{detail}" if detail
    puts line
  end

  def headers(token = @token)
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  def request(method, path, body: nil, token: @token)
    uri = URI("#{BASE}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 5
    http.read_timeout = 30

    klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(method) do
      raise ArgumentError, "Unsupported HTTP method: #{method.inspect}"
    end

    req = klass.new(uri, headers(token))
    req.body = body.to_json if body
    http.request(req)
  end

  def json(res)
    JSON.parse(res.body, symbolize_names: true)
  rescue JSON::ParserError
    { raw: res.body }
  end

  def create_commitment(overrides = {})
    body = {
      name: "Smoke #{SecureRandom.hex(4)}",
      category: "debt",
      recurrence: "monthly",
      amount: 100,
      start_date: Date.current,
      **overrides
    }
    res = request(:post, "/commitments", body: { commitment: body })
    data = json(res)
    [res, data]
  end

  def transition(id, action)
    request(:post, "/commitments/#{id}/#{action}")
  end

  def fetch_summary
    res = request(:get, "/summary")
    [res, json(res)[:summary]]
  end

  def fetch_breakdown
    res = request(:get, "/breakdown")
    [res, json(res)[:breakdown]]
  end

  def base_params
    {
      name: "Test",
      category: "debt",
      recurrence: "monthly",
      amount: 100,
      start_date: Date.current
    }
  end

  def test_creation
    res, data = create_commitment(start_date: Date.current)
    record("start_date=today → active", data[:status] == "active" && res.code == "201", "status=#{data[:status]}")

    res, data = create_commitment(start_date: Date.current - 7)
    record("start_date=past → active", data[:status] == "active", "status=#{data[:status]}")

    res, data = create_commitment(start_date: Date.current + 7)
    record("start_date=future → scheduled", data[:status] == "scheduled" && res.code == "201", "status=#{data[:status]}")

    res, data = create_commitment(category: "aaa")
    record("invalid category → 422", res.code == "422", "code=#{res.code} errors=#{data[:errors]}")

    res, data = create_commitment(recurrence: "aaa")
    record("invalid recurrence → 422", res.code == "422", "code=#{res.code}")

    create_commitment
    res2 = request(:post, "/commitments", body: { commitment: base_params.merge(status: "paused") })
    data2 = json(res2)
    record("invalid status param ignored → active", data2[:status] == "active", "status=#{data2[:status]}")

    res = request(:post, "/commitments", body: { commitment: { name: nil, category: "debt", amount: 100, start_date: Date.current, recurrence: "monthly" } })
    data = json(res)
    record("missing required fields → 422", res.code == "422" && data[:errors].present?, "code=#{res.code}")
  end

  def test_pause
    _, active = create_commitment
    id = active[:id]

    res = transition(id, :pause)
    data = json(res)
    record("active → paused", res.code == "200" && data[:status] == "paused")

    res = transition(id, :pause)
    record("paused → paused (422)", res.code == "422")

    _, scheduled = create_commitment(start_date: Date.current + 7)
    res = transition(scheduled[:id], :pause)
    record("scheduled → paused (422)", res.code == "422")

    _, cancelled = create_commitment
    transition(cancelled[:id], :cancel)
    res = transition(cancelled[:id], :pause)
    record("cancelled → paused (422)", res.code == "422")

    completed = Commitment.create!(
      user: @user, name: "Completed", category: :debt, recurrence: :monthly,
      amount: 50, start_date: Date.current - 7
    )
    completed.update_column(:status, Commitment.statuses[:completed])
    res = transition(completed.id, :pause)
    record("completed → paused (422)", res.code == "422")
  end

  def test_resume
    _, active = create_commitment
    transition(active[:id], :pause)
    res = transition(active[:id], :resume)
    record("paused → active", res.code == "200" && json(res)[:status] == "active")

    _, active2 = create_commitment
    res = transition(active2[:id], :resume)
    record("active → resume (422)", res.code == "422")

    _, scheduled = create_commitment(start_date: Date.current + 7)
    res = transition(scheduled[:id], :resume)
    record("scheduled → resume (422)", res.code == "422")

    _, cancelled = create_commitment
    transition(cancelled[:id], :cancel)
    res = transition(cancelled[:id], :resume)
    record("cancelled → resume (422)", res.code == "422")

    completed = Commitment.create!(
      user: @user, name: "Completed2", category: :debt, recurrence: :monthly,
      amount: 50, start_date: Date.current - 7
    )
    completed.update_column(:status, Commitment.statuses[:completed])
    res = transition(completed.id, :resume)
    record("completed → resume (422)", res.code == "422")
  end

  def test_cancel
    _, active = create_commitment
    res = transition(active[:id], :cancel)
    record("active → cancelled", res.code == "200" && json(res)[:status] == "cancelled")

    _, paused = create_commitment
    transition(paused[:id], :pause)
    res = transition(paused[:id], :cancel)
    record("paused → cancelled", res.code == "200")

    _, scheduled = create_commitment(start_date: Date.current + 7)
    res = transition(scheduled[:id], :cancel)
    record("scheduled → cancelled", res.code == "200")

    _, cancelled = create_commitment
    transition(cancelled[:id], :cancel)
    res = transition(cancelled[:id], :cancel)
    record("cancelled → cancel (422)", res.code == "422")

    completed = Commitment.create!(
      user: @user, name: "Completed3", category: :debt, recurrence: :monthly,
      amount: 50, start_date: Date.current - 7
    )
    completed.update_column(:status, Commitment.statuses[:completed])
    res = transition(completed.id, :cancel)
    record("completed → cancel (422)", res.code == "422")
  end

  def test_financials
    fin_user = User.create!(
      email: "smoke-fin-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      monthly_income: 4000,
      savings: 3050
    )
    original_token = @token
    @token = JwtService.encode(user_id: fin_user.id)

    states = {
      active: { start_date: Date.current, amount: 100, category: "debt" },
      scheduled: { start_date: Date.current + 7, amount: 200, category: "obligation" },
      paused: { start_date: Date.current, amount: 300, category: "service" },
      cancelled: { start_date: Date.current, amount: 400, category: "investment" },
      completed: { start_date: Date.current, amount: 500, category: "investment" }
    }

    ids = {}
    states.each do |state, attrs|
      _res, data = create_commitment(name: "FinCalc #{state}", **attrs)
      ids[state] = data[:id]
      case state
      when :paused then transition(data[:id], :pause)
      when :cancelled then transition(data[:id], :cancel)
      when :completed
        Commitment.find(data[:id]).update_column(:status, Commitment.statuses[:completed])
      end
    end

    _, summary = fetch_summary
    _, breakdown = fetch_breakdown

    record("summary: only active in monthly_commitments_amount",
           summary[:monthly_commitments_amount] == "100.00",
           "got #{summary[:monthly_commitments_amount]}")

    record("breakdown: only active debt",
           breakdown[:debt] == "100.00" && breakdown[:obligation] == "0.00",
           "debt=#{breakdown[:debt]} obligation=#{breakdown[:obligation]}")

    %i[scheduled paused cancelled completed].each do |state|
      amount = BigDecimal(states[state][:amount].to_s)
      record("breakdown excludes #{state}",
             breakdown.values.none? { |v| BigDecimal(v) >= amount })
    end

    record("breakdown returns all categories",
           breakdown.keys.map(&:to_s).sort == Commitment.categories.keys.sort)

    record("empty categories return 0.00",
           breakdown[:service] == "0.00" && breakdown[:investment] == "0.00")

    record("summary: monthly_income", summary[:monthly_income] == "4000.00")
    record("summary: savings", summary[:savings] == "3050.00")

    record("summary: available_cash_flow",
           summary[:available_cash_flow] == "3900.00",
           "got #{summary[:available_cash_flow]}")

    record("summary: savings_runway_months",
           summary[:savings_runway_months].to_s == "30.5",
           "got #{summary[:savings_runway_months]}")

    transition(ids[:active], :pause)
    _, summary_after_pause = fetch_summary
    record("summary after pause → 0 commitments",
           summary_after_pause[:monthly_commitments_amount] == "0.00",
           "got #{summary_after_pause[:monthly_commitments_amount]}")

    transition(ids[:active], :resume)
    _, summary_after_resume = fetch_summary
    record("summary after resume → active counted",
           summary_after_resume[:monthly_commitments_amount] == "100.00")

    transition(ids[:active], :cancel)
    _, summary_after_cancel = fetch_summary
    record("summary after cancel → 0 commitments",
           summary_after_cancel[:monthly_commitments_amount] == "0.00")

    @token = original_token
  end

  def test_validation
    res, = create_commitment(category: "bogus")
    record("invalid category no 500", res.code == "422" && res.code != "500")

    res, = create_commitment(recurrence: "bogus")
    record("invalid recurrence no 500", res.code == "422")

    res, = request(:post, "/commitments", body: { commitment: base_params.merge(status: "bogus") })
    record("invalid status param no 500", res.code != "500")

    res, = request(:post, "/commitments", body: { not_commitment: {} })
    record("malformed payload handled", %w[400 422].include?(res.code), "code=#{res.code}")
  end

  def test_authorization
    other = User.create!(email: "smoke-other-#{SecureRandom.hex(4)}@example.com", password: "password")
    other_token = JwtService.encode(user_id: other.id)
    _, mine = create_commitment
    res = request(:post, "/commitments/#{mine[:id]}/pause", token: other_token)
    record("other user cannot pause", res.code == "404", "code=#{res.code}")
    record("commitment still active", Commitment.find(mine[:id]).active?)
  end

  def test_edge_cases
    _, data = create_commitment(start_date: Date.current, amount: 99.99)
    record("starts today", data[:status] == "active")

    _, data = create_commitment(start_date: Date.current + 1)
    record("starts tomorrow → scheduled", data[:status] == "scheduled")

    _, data = create_commitment(amount: 123.45)
    record("decimal amount preserved", data[:amount] == "123.45")

    _, rapid = create_commitment(amount: 50)
    id = rapid[:id]
    transition(id, :pause)
    transition(id, :resume)
    res = transition(id, :cancel)
    record("rapid pause→resume→cancel", res.code == "200" && json(res)[:status] == "cancelled")
  end

  def print_summary
    passed = @results.count { |r| r[:pass] }
    failed = @results.count { |r| !r[:pass] }
    puts "\n" + "=" * 60
    puts "RESULTS: #{passed} passed, #{failed} failed, #{@results.size} total"
    if failed.positive?
      puts "\nFailures:"
      @results.reject { |r| r[:pass] }.each { |r| puts "  - #{r[:name]}: #{r[:detail]}" }
      exit 1
    end
    puts "All checks passed."
  end
end

SmokeTest.new.run
