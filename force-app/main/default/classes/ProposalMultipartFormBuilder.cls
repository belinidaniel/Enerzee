/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-13-2026
 * @last modified by  : Daniel Belini
 * @test              : NO_TESTS_MAPPED
 **/
public with sharing class ProposalMultipartFormBuilder {
  private static final String BOUNDARY = '1ff13444ed8140c7a32fc4e6451aa76d';

  public enum EndingType {
    Cr,
    CrLf,
    None
  }

  public class WriteFileResult {
    public String content { get; private set; }
    public EndingType endingType { get; private set; }

    public WriteFileResult(String contentValue, EndingType endingTypeValue) {
      content = contentValue;
      endingType = endingTypeValue;
    }
  }

  public static String getContentType() {
    return 'multipart/form-data; charset="UTF-8"; boundary="' + BOUNDARY + '"';
  }

  public static Blob compose(
    Map<String, String> bodyParameters,
    String fileFieldName,
    String fileName,
    String mimeType,
    Blob fileBlob
  ) {
    if (String.isBlank(fileFieldName) || fileBlob == null) {
      throw new AuraHandledException(
        'Arquivo invalido para composicao do multipart.'
      );
    }

    List<String> keys = new List<String>();
    if (bodyParameters != null) {
      keys.addAll(bodyParameters.keySet());
      keys.sort();
    }

    String form64 = '';
    for (String key : keys) {
      form64 += writeBoundary();
      form64 += writeBodyParameter(key, bodyParameters.get(key));
    }
    form64 += writeBoundary();

    WriteFileResult fileResult = writeFile(
      fileFieldName,
      fileName,
      mimeType,
      fileBlob
    );
    form64 += fileResult.content;
    form64 += writeBoundary(fileResult.endingType);

    return EncodingUtil.base64Decode(form64);
  }

  public static String writeBoundary() {
    return EncodingUtil.base64Encode(Blob.valueOf('--' + BOUNDARY + '\r\n'));
  }

  public static String writeBoundary(EndingType ending) {
    String value = '';
    if (ending == EndingType.Cr) {
      value += '\n';
    } else if (ending == EndingType.None) {
      value += '\r\n';
    }
    value += '--' + BOUNDARY + '--';
    return EncodingUtil.base64Encode(Blob.valueOf(value));
  }

  public static String writeBodyParameter(String key, String value) {
    String safeValue = value == null ? '' : value;
    String contentDisposition =
      'Content-Disposition: form-data; name="' +
      key +
      '"';
    String contentDispositionCrLf = contentDisposition + '\r\n\r\n';
    String contentDispositionCrLf64 = EncodingUtil.base64Encode(
      Blob.valueOf(contentDispositionCrLf)
    );
    String content = safelyPad(
      contentDisposition,
      contentDispositionCrLf64,
      '\r\n\r\n'
    );

    String valueCrLf64 = EncodingUtil.base64Encode(
      Blob.valueOf(safeValue + '\r\n')
    );
    content += safelyPad(safeValue, valueCrLf64, '\r\n');
    return content;
  }

  public static WriteFileResult writeFile(
    String key,
    String value,
    String mimeType,
    Blob fileBlob
  ) {
    EndingType ending = EndingType.None;
    String safeFileName = String.isBlank(value) ? 'template.pptx' : value;
    String safeMimeType = String.isBlank(mimeType)
      ? 'application/octet-stream'
      : mimeType;

    String contentDisposition =
      'Content-Disposition: form-data; name="' +
      key +
      '"; filename="' +
      safeFileName +
      '"';
    String content = safelyPad(
      contentDisposition,
      EncodingUtil.base64Encode(Blob.valueOf(contentDisposition + '\r\n')),
      '\r\n'
    );

    String contentType = 'Content-Type: ' + safeMimeType;
    content += safelyPad(
      contentType,
      EncodingUtil.base64Encode(Blob.valueOf(contentType + '\r\n\r\n')),
      '\r\n\r\n'
    );

    String file64 = EncodingUtil.base64Encode(fileBlob);
    String file64Ending = file64.substring(
      file64.length() - 3,
      file64.length()
    );
    if (file64Ending.endsWith('==')) {
      file64Ending = file64Ending.substring(0, 1) + '0K';
      file64 = file64.substring(0, file64.length() - 3) + file64Ending;
      ending = EndingType.CrLf;
    } else if (file64Ending.endsWith('=')) {
      file64Ending = file64Ending.substring(0, 2) + 'N';
      file64 = file64.substring(0, file64.length() - 3) + file64Ending;
      ending = EndingType.Cr;
    }
    content += file64;

    return new WriteFileResult(content, ending);
  }

  private static String safelyPad(
    String value,
    String valueCrLf64,
    String lineBreaks
  ) {
    String safeValue = value == null ? '' : value;
    String encoded = valueCrLf64;
    while (encoded.endsWith('=')) {
      safeValue += ' ';
      encoded = EncodingUtil.base64Encode(Blob.valueOf(safeValue + lineBreaks));
    }
    return encoded;
  }
}
