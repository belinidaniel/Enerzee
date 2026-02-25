public with sharing class IntegrationHubService {
  private static final String NIVELLO_ENDPOINT_HINT = 'geradorproposta';
  public static final String PROVIDER_NIVELLO = 'NIVELLO';
  public static final String PROVIDER_VO = 'VO';

  public static HttpResponse send(HttpRequest request) {
    if (request == null) {
      throw new IntegrationHubException('HttpRequest não informado.');
    }

    String provider = resolveProvider(request.getEndpoint());
    return send(request, provider);
  }

  public static HttpResponse send(HttpRequest request, String provider) {
    if (request == null) {
      throw new IntegrationHubException('HttpRequest não informado.');
    }

    String targetProvider = String.isBlank(provider) ? PROVIDER_VO : provider;

    if (targetProvider == PROVIDER_NIVELLO) {
      return Utils.callIntegrationNivello(request);
    }

    return Utils.callIntegrationVO(request);
  }

  public static String resolveProvider(String endpoint) {
    String normalizedEndpoint = endpoint == null ? '' : endpoint.toLowerCase();

    if (normalizedEndpoint.contains(NIVELLO_ENDPOINT_HINT)) {
      return PROVIDER_NIVELLO;
    }

    return PROVIDER_VO;
  }

  public class IntegrationHubException extends Exception {
  }
}
