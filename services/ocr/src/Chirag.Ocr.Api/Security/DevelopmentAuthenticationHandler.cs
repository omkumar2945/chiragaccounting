using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace Chirag.Ocr.Api.Security;

public sealed class DevelopmentAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var clientId = Request.Headers["X-Client-Id"].FirstOrDefault() ?? "demo-company";
        var accountantId = Request.Headers["X-Accountant-Id"].FirstOrDefault() ?? "demo-accountant";
        var role = Request.Headers["X-Role"].FirstOrDefault() is "Client" ? "Client" : "Accountant";
        var claims = new[] { new Claim("client_id", clientId), new Claim(ClaimTypes.NameIdentifier, accountantId),
            new Claim(ClaimTypes.Name, accountantId), new Claim(ClaimTypes.Role, role) };
        var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, Scheme.Name));
        return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(principal, Scheme.Name)));
    }
}