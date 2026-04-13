/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-13-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalPayloadBuilder {
  private static final Pattern SAFE_PATH_PATTERN = Pattern.compile(
    '^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)*$'
  );

  public class Payload {
    public Map<String, String> tags = new Map<String, String>();
    public List<String> sectionsToShow = new List<String>();
    public String tagsJson;
    public String sectionsJson;
    public String payloadHash;
  }

  public static Opportunity queryOpportunityForTags(
    Id opportunityId,
    List<ProposalConfigurationService.TagConfig> tagConfigs
  ) {
    Set<String> selectFields = new Set<String>{ 'Id' };
    if (tagConfigs != null) {
      for (ProposalConfigurationService.TagConfig config : tagConfigs) {
        if (String.isBlank(config.sourcePath)) {
          continue;
        }
        if (ProposalComputedValueService.isComputedPath(config.sourcePath)) {
          continue;
        }
        validatePath(config.sourcePath);
        selectFields.add(config.sourcePath);
      }
    }

    List<String> fieldList = new List<String>();
    fieldList.addAll(selectFields);
    fieldList.sort();

    String query =
      'SELECT ' +
      String.join(fieldList, ', ') +
      ' FROM Opportunity WHERE Id = :opportunityId';
    return (Opportunity) Database.query(query);
  }

  public static Payload buildPayload(
    ProposalContextResolver.Context context,
    Opportunity opportunityRecord,
    List<ProposalConfigurationService.TagConfig> tagConfigs,
    List<String> sectionsToShow,
    Id templateVersionId
  ) {
    if (context == null || opportunityRecord == null) {
      throw new AuraHandledException(
        'Contexto insuficiente para montar o payload.'
      );
    }

    Payload payload = new Payload();
    Map<String, Object> computedValues = ProposalComputedValueService.build(
      context.opportunity.Id,
      opportunityRecord
    );
    payload.sectionsToShow = sectionsToShow == null
      ? new List<String>()
      : new List<String>(sectionsToShow);

    if (tagConfigs != null) {
      for (ProposalConfigurationService.TagConfig config : tagConfigs) {
        String resolvedValue = resolveTagValue(
          opportunityRecord,
          config,
          computedValues
        );
        payload.tags.put(config.tagKey, resolvedValue);
      }
    }

    payload.tagsJson = JSON.serialize(payload.tags);
    payload.sectionsJson = JSON.serialize(payload.sectionsToShow);
    payload.payloadHash = generateHash(
      String.join(
        new List<String>{
          String.valueOf(context.cover.Id),
          String.valueOf(templateVersionId),
          payload.tagsJson,
          payload.sectionsJson
        },
        '|'
      )
    );
    return payload;
  }

  private static String resolveTagValue(
    Opportunity opportunityRecord,
    ProposalConfigurationService.TagConfig config,
    Map<String, Object> computedValues
  ) {
    Object rawValue = ProposalComputedValueService.isComputedPath(
        config.sourcePath
      )
      ? ProposalComputedValueService.resolveValue(
          config.sourcePath,
          computedValues
        )
      : extractValue(opportunityRecord, config.sourcePath);
    if (rawValue == null) {
      rawValue = config.defaultValue;
    }
    if (rawValue == null && config.required == true) {
      throw new AuraHandledException(
        'Campo obrigatorio nao encontrado para a tag ' + config.tagKey + '.'
      );
    }
    return formatValue(rawValue, config.formatValue);
  }

  private static Object extractValue(SObject source, String path) {
    if (source == null || String.isBlank(path)) {
      return null;
    }
    List<String> parts = path.split('\\.');
    SObject current = source;
    for (Integer index = 0; index < parts.size() - 1; index++) {
      current = current == null ? null : current.getSObject(parts[index]);
      if (current == null) {
        return null;
      }
    }
    return current.get(parts[parts.size() - 1]);
  }

  private static void validatePath(String path) {
    if (!SAFE_PATH_PATTERN.matcher(path).matches()) {
      throw new AuraHandledException(
        'SourcePath invalido para a configuracao de proposta: ' + path
      );
    }
  }

  private static String formatValue(Object value, String formatValue) {
    if (value == null) {
      return '';
    }

    String normalizedFormat = String.isBlank(formatValue)
      ? ProposalConfigurationService.FORMAT_RAW
      : formatValue.trim().toUpperCase();
    if (normalizedFormat == 'UPPER') {
      return String.valueOf(value).toUpperCase();
    }
    if (normalizedFormat == 'LOWER') {
      return String.valueOf(value).toLowerCase();
    }
    if (normalizedFormat == 'DATE_BR') {
      if (value instanceof Date) {
        Date rawDate = (Date) value;
        return Datetime.newInstance(
            rawDate.year(),
            rawDate.month(),
            rawDate.day(),
            0,
            0,
            0
          )
          .format('dd/MM/yyyy');
      }
      if (value instanceof Datetime) {
        return ((Datetime) value).format('dd/MM/yyyy');
      }
    }
    if (normalizedFormat == 'INTEGER') {
      Decimal decimalValue = toDecimal(value);
      return decimalValue == null
        ? String.valueOf(value)
        : String.valueOf(decimalValue.setScale(0));
    }
    if (normalizedFormat == 'DECIMAL_BR') {
      Decimal decimalValue = toDecimal(value);
      if (decimalValue == null) {
        return String.valueOf(value);
      }
      return formatDecimalBR(decimalValue, 2);
    }
    if (normalizedFormat == 'CURRENCY_BR') {
      Decimal decimalValue = toDecimal(value);
      if (decimalValue == null) {
        return String.valueOf(value);
      }
      return formatDecimalBR(decimalValue, 2);
    }

    return String.valueOf(value);
  }

  private static String formatDecimalBR(Decimal value, Integer scale) {
    Decimal scaled = value.setScale(scale, RoundingMode.HALF_UP);
    Long integerPart = scaled.longValue();
    Decimal fractionalPart = (scaled - integerPart)
      .abs()
      .setScale(scale, RoundingMode.HALF_UP);

    String intStr = String.valueOf(
      integerPart < 0 ? -integerPart : integerPart
    );
    String intFormatted = '';
    Integer remainder = Math.mod(intStr.length(), 3);
    for (Integer i = 0; i < intStr.length(); i++) {
      if (i > 0 && Math.mod(i - remainder, 3) == 0 && i >= remainder) {
        intFormatted += '.';
      }
      intFormatted += intStr.substring(i, i + 1);
    }

    String fracStr = String.valueOf(fractionalPart).replace('0.', '');
    while (fracStr.length() < scale) {
      fracStr += '0';
    }

    String result = intFormatted + ',' + fracStr;
    return integerPart < 0 ? '-' + result : result;
  }

  private static Decimal toDecimal(Object value) {
    try {
      if (value instanceof Decimal) {
        return (Decimal) value;
      }
      return Decimal.valueOf(String.valueOf(value));
    } catch (Exception e) {
      return null;
    }
  }

  private static String generateHash(String rawValue) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('SHA-256', Blob.valueOf(rawValue))
    );
  }
}
