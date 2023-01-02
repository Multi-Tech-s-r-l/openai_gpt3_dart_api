import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:openai_gpt3_api/files.dart';
import 'package:openai_gpt3_api/search.dart';
import 'package:universal_io/io.dart';

import 'answer.dart';
import 'classification.dart';
import 'completion.dart';
import 'invalid_request_exception.dart';

class GPT3 {
  String apiKey;


  /// Creates the OpenAI GPT-3 helper object.
  ///
  /// You should inject your personal API-key to the program by adding
  /// --dart-define=OPENAI_API_KEY=${OPENAI_API_KEY}
  /// to your flutter arguments.
  GPT3(String apiKey) : apiKey = apiKey;

  Uri _getUri(String apiEndpoint, [Engine engine = Engine.davinci]) {
    if (apiEndpoint == 'classifications' ||
        apiEndpoint == 'answers' ||
        apiEndpoint.startsWith('files')) {
      return Uri.https('api.openai.com', '/v1/$apiEndpoint');
    }
    return Uri.https(
        'api.openai.com', '/v1/$apiEndpoint');
  }
  Future<HttpClientResponse> _postHttpCall(Uri url, dynamic parameter,
      {int connectionTimeout = -1, int closeConnectionTimeout = -1}) async {
    /// Controllo certificato annullato su Android
    final client = HttpClient();//..badCertificateCallback = _certificateCheck;
    //client.badCertificateCallback = _certificateCheck;
    client.connectionTimeout = Duration(
        milliseconds: connectionTimeout == -1
            ? 30000
            : connectionTimeout);

    var request = await client.postUrl(url);

    request.headers.add("Content-Type", "application/json; charset=UTF-8");
    request.headers.add(HttpHeaders.authorizationHeader,
        'Bearer $apiKey');

    /*if (request is BrowserHttpClientRequest) {
        request.browserCredentialsMode = true;
      }*/
    //print(request.toString());
    if (parameter != null) {

        print(jsonEncode(parameter));

      request.write(jsonEncode(parameter));
    }

    try {
      return await request.close().timeout(Duration(
          milliseconds: closeConnectionTimeout == -1
              ? 30000
              : closeConnectionTimeout));
    } catch (e) {

        print(e);

      rethrow;
    }
  }
  /// Post a HTTP call to the given [url] with the data object [body].
  Future<Response> _postHttpCallOld(Uri url, Map<String, dynamic> body) {
    return http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
        'Content-type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body),
    );
  }

  /// Catch any exceptions from the GPT-3 backend.
  void _catchExceptions(Map<String, dynamic> data) {
    if (data.containsKey('error')) {
      throw InvalidRequestException.fromJson(data['error']);
    }
  }

  /// Post a 'completion' API request to the OpenAI service.
  ///
  /// Throws an [InvalidRequestException] if something goes wrong on the backend.
  ///
  /// For more information, refer to [the OpenAI documentation](https://beta.openai.com/docs/api-reference/completions/create).
  Future<CompletionApiResult> completion(String prompt,
      {int maxTokens = 16,
      num temperature = 1,
      num topP = 1,
      int n = 1,
      bool stream = false,
      int? logProbs,
      bool echo = false,
      Engine engine = Engine.davinci,
        String model = 'text-davinci-003',
      String? stop,
      num presencePenalty = 0,
      num frequencyPenalty = 0,
      int bestOf = 1,
      Map<String, num>? logitBias,
        Function(String rx)? onRx}) async {
    var data = CompletionApiParameters(prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        model: model,
        bestOf: bestOf,
        echo: echo,
        frequencyPenalty: frequencyPenalty,
        logitBias: logitBias,
        logprobs: logProbs,
        n: n,
        presencePenalty: presencePenalty,
        stop: stop,
        stream: stream,
        topP: topP, onRx: onRx);

    var reqData = data.toJson();
    var response = await _postHttpCall(_getUri('completions', engine), reqData);
    var result;
    if (stream){
      result = await readResponse(response, onRx: onRx);
      return result;
    } else {
      result = await readResponseSync(response);
      Map<String, dynamic> map = json.decode(result);
      _catchExceptions(map);
      return CompletionApiResult.fromJson(map);
    }




  }

  Future<HttpClientResponse> streamCompletion(String prompt,
      {int maxTokens = 16,
        num temperature = 1,
        num topP = 1,
        int n = 1,
        bool stream = false,
        int? logProbs,
        bool echo = false,
        Engine engine = Engine.davinci,
        String model = 'text-davinci-003',
        String? stop,
        num presencePenalty = 0,
        num frequencyPenalty = 0,
        int bestOf = 1,
        Map<String, num>? logitBias,
        Function(String rx)? onRx}) async {
    var data = CompletionApiParameters(prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        model: model,
        bestOf: bestOf,
        echo: echo,
        frequencyPenalty: frequencyPenalty,
        logitBias: logitBias,
        logprobs: logProbs,
        n: n,
        presencePenalty: presencePenalty,
        stop: stop,
        stream: stream,
        topP: topP, onRx: onRx);

    var reqData = data.toJson();
    var response = await _postHttpCall(_getUri('completions', engine), reqData);
    /*var result;
    if (stream){
      result = await readResponse(response, onRx: onRx);
      return result;
    } else {
      result = await readResponseSync(response);
      Map<String, dynamic> map = json.decode(result);
      _catchExceptions(map);
      return CompletionApiResult.fromJson(map);
    }*/

    return response;


  }
  Future<CompletionApiResult> readResponse(HttpClientResponse response, {Function(String rx)? onRx}) async {
    //final completer = Completer<String>();
    CompletionApiResult? result;
    var n=0;
    final contents = StringBuffer();
    response.transform(utf8.decoder).listen((data) {

      Map<String, dynamic> map = json.decode(data.substring(5));
      _catchExceptions(map);
      var res = CompletionApiResult.fromJson(map);

      result=res;

      contents.write(res.choices.first.text);
      onRx?.call(contents.toString());
      n++;
    }, onDone: () => {
      result = CompletionApiResult(result!.id, result!.object, result!.created, result!.model, List.generate(1, (index) => Choice(contents.toString(), index, result!.choices[index].finishReason)))
    });
    //return completer.future;
    /*response.transform(utf8.decoder).listen((data) {
      onRx?.call(data);
      contents.write(data);
    }
    );*/

    /*await for (var data in response.transform(utf8.decoder)) {
      contents.write(data);
    }*/

    return result!;
  }
  Future<String> readResponseSync(HttpClientResponse response) async {

    final contents = StringBuffer();

    await for (var data in response.transform(utf8.decoder)) {
      contents.write(data);
    }

    return contents.toString();
  }
  /// Given a query and a set of documents or labels, the model ranks each
  /// document based on its semantic similarity to the provided [query].
  ///
  /// If [documents] and [file] are both null or both not-null, a [ArgumentError] is thrown.
  /// Throws an [InvalidRequestException] if something goes wrong on the backend.
  /// For more information, refer to [the OpenAI documentation](https://beta.openai.com/docs/api-reference/searches)
  Future<SearchApiResult> search(String query,
      {List<String>? documents,
      String? file,
      int maxRerank = 200,
      bool returnMetadata = false,
      Engine engine = Engine.davinci}) async {
    var data = SearchApiParameters(query,
        documents: documents,
        file: file,
        maxRerank: maxRerank,
        returnMetadata: returnMetadata);
    var reqData = data.toJson();
    var response = await _postHttpCall(_getUri('search', engine), reqData);
    var result = await readResponseSync(response);
    Map<String, dynamic> map = json.decode(result);
    _catchExceptions(map);
    return SearchApiResult.fromJson(map);
  }

  /// Classifies the specified query using provided examples.
  ///
  /// The endpoint first searches over the labeled examples to select the
  /// ones most relevant for the particular query. Then, the relevant examples
  /// are combined with the query to construct a prompt to produce the final
  /// label via the completions endpoint.
  ///
  /// Labeled examples can be provided via an uploaded file, or explicitly
  /// listed in the request using the examples parameter for quick tests
  /// and small scale use cases.
  ///
  /// If [examples] and [file] are both null or both not-null, a [ArgumentError] is thrown.
  /// Throws an [InvalidRequestException] if something goes wrong on the backend.
  ///
  /// For more information, refer to [the OpenAI documentation](https://beta.openai.com/docs/api-reference/classifications)
  Future<ClassificationApiResult> classification(Engine model, String query,
      {List<List<String>>? examples,
      String? file,
      List<String>? labels,
      Engine searchModel = Engine.ada,
      num temperature = 0,
      int? logprobs,
      int maxExamples = 200,
      Map<String, num>? logitBias,
      bool returnPrompt = false,
      bool returnMetadata = false,
      List<String>? expand}) async {
    var data = ClassificationApiParameters(model.toString(), query,
        returnMetadata: returnMetadata,
        file: file,
        logitBias: logitBias,
        temperature: temperature,
        examples: examples,
        expand: expand,
        labels: labels,
        logprobs: logprobs,
        maxExamples: maxExamples,
        returnPrompt: returnPrompt,
        searchModel: searchModel.toString());
    var reqData = data.toJson();
    var response = await _postHttpCall(_getUri('classifications'), reqData);
    var result = await readResponseSync(response);
    Map<String, dynamic> map = json.decode(result);
    _catchExceptions(map);
    return ClassificationApiResult.fromJson(map);
  }

  /// Answers the specified question using the provided documents and examples.
  ///
  /// The endpoint first searches over provided documents or files to find
  /// relevant context. The relevant context is combined with the provided
  /// examples and question to create the prompt for completion.
  ///
  /// If [documents] and [file] are both null or both not-null, a [ArgumentError] is thrown.
  /// Throws an [InvalidRequestException] if something goes wrong on the backend.
  ///
  /// For more information, refer to [the OpenAI documentation](https://beta.openai.com/docs/api-reference/answers)
  Future<AnswerApiResult> answer(Engine model, String question,
      List<List<String>> examples, String examplesContext,
      {List<String>? documents,
      String? file,
      Engine searchModel = Engine.ada,
      int maxRerank = 200,
      num temperature = 0,
      int? logprobs,
      int maxTokens = 16,
      List<String>? stop,
      int n = 1,
      Map<String, num>? logitBias,
      bool returnMetadata = false,
      bool returnPrompt = false,
      List<String>? expand}) async {
    var data = AnswerApiParameters(
        model.toString(), question, examples, examplesContext,
        documents: documents,
        file: file,
        searchModel: searchModel.toString(),
        maxRerank: maxRerank,
        temperature: temperature,
        logprobs: logprobs,
        maxTokens: maxTokens,
        stop: stop,
        n: n,
        logitBias: logitBias,
        returnPrompt: returnPrompt,
        returnMetadata: returnMetadata,
        expand: expand);
    var reqData = data.toJson();
    var response = await _postHttpCall(_getUri('answers'), reqData);
    var result = await readResponseSync(response);
    Map<String, dynamic> map = json.decode(result);
    _catchExceptions(map);
    return AnswerApiResult.fromJson(map);
  }

  /// Returns a list of files that belong to the user's organization.
  ///
  /// Throws an [InvalidRequestException] if something goes wrong on the backend.
  ///
  /// For more information, refer to [the OpenAI documentation](https://beta.openai.com/docs/api-reference/files/list)
  Future<ListFilesApiResult> listFiles() async {
    var response = await http.get(
      _getUri('files'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );
    Map<String, dynamic> map = json.decode(response.body);
    _catchExceptions(map);
    return ListFilesApiResult.fromJson(map);
  }

  /// Upload a file that contains document(s) to be used across various endpoints/features.
  ///
  /// Throws an [InvalidRequestException] if something goes wrong on the backend.
  ///
  /// For more information, refer to [the OpenAI documentation](https://beta.openai.com/docs/api-reference/files/upload)
  Future<UploadedFile> uploadFile(String filePath, String purpose) async {
    var request = http.MultipartRequest('POST', _getUri('files'));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['-F'] = 'purpose=\"$purpose\"';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.files.add(http.MultipartFile.fromString('purpose', purpose));
    var response = await request.send();
    Map<String, dynamic> map =
        json.decode(await response.stream.bytesToString());
    _catchExceptions(map);
    return UploadedFile.fromJson(map);
  }

  /// Returns information about the file with the unique [id].
  ///
  /// Throws an [InvalidRequestException] if something goes wrong on the backend.
  ///
  /// For more information, refer to [the OpenAI documentation](https://beta.openai.com/docs/api-reference/files/retrieve)
  Future<UploadedFile> retrieveFile(String id) async {
    var response = await http.get(
      _getUri('files/$id'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );
    Map<String, dynamic> map = json.decode(response.body);
    _catchExceptions(map);
    return UploadedFile.fromJson(map);
  }

  /// Delete a file by its [id]. Only owners of organizations can delete files currently.
  ///
  /// Throws an [InvalidRequestException] if something goes wrong on the backend.
  ///
  /// For more information, refer to [the OpenAI documentation](https://beta.openai.com/docs/api-reference/files/delete)
  Future<void> deleteFile(String id) async {
    var response = await http.delete(
      _getUri('files/$id'),
      headers: {'Authorization': 'Bearer $apiKey'},
    );
    Map<String, dynamic> map = json.decode(response.body);
    _catchExceptions(map);
    return;
  }
}

/// The OpenAI GPT-3 engine used in the API call.
///
/// For more information on the engines, refer to [the OpenAI documentation](https://beta.openai.com/docs/engines).
class Engine {
  static const ada = Engine._('text-ada-001');
  static const babbage = Engine._('text-babbage-001');
  static const curie = Engine._('text-curie-001');
  static const davinci = Engine._('text-davinci-002');
  static const davinci2 = Engine._('text-davinci-002');
  static const davinci3 = Engine._('text-davinci-003');
  static const davinci_instruct = Engine._('davinci-instruct-beta');
  final String _string;

  const Engine._(this._string);

  @override
  String toString() => _string;
}
