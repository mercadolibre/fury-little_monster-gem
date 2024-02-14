class LoginSharkMock
  def initialize(rspec_context)
    @rspec_context = rspec_context
  end

  def login_request_success(body)
    headers = { 'Content-Type' => 'application/json'}
    @rspec_context.stub_request(:post, %r{.*/login/shark}).to_return(status: 201, headers: headers, body: body)
  end

  def login_request_failure
    @rspec_context.stub_request(:post, %r{.*/login/shark}).to_return(status: 401)
  end
end
