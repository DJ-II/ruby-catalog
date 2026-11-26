# Run using bin/ci

abort 'Unset DATABASE_URL before running local CI.' unless ENV['DATABASE_URL'].to_s.empty?
ENV['RAILS_ENV'] = 'test'
ENV['PARALLEL_WORKERS'] = '1'

CI.run do
  step 'Setup: Test database', 'bundle exec ruby bin/rails db:prepare'
  step 'Security: Gem audit', 'bundle exec bundler-audit check --update'
  step 'Security: Brakeman code analysis', 'bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error'
  step 'Tests: Rails', 'bundle exec ruby bin/rails test'

  # Optional: Run system tests
  # step "Tests: System", "bin/rails test:system"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
