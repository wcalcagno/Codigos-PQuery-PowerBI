let
 // Primero concatenamos la <Consumer Key> & <Consumer Secret> para convertirlos a base64
 authKey = "Basic " & Binary.ToText(Text.ToBinary("<ConsumerKey>:<ConsumerSecret>"),0),
 url = "https://api.twitter.com/oauth2/token",

 // Usamos el  Twitter POST oauth2/token para obtener un Token y poder buscar en la API
 GetJson = Web.Contents(url,
     [
         Headers = [#"Authorization"=authKey,
                    #"Content-Type"="application/x-www-form-urlencoded;charset=UTF-8"],
         Content = Text.ToBinary("grant_type=client_credentials") 
     ]
 ),
 FormatAsJson = Json.Document(GetJson),

 // Obtenemos el  token desde la respuesta en Json
 AccessToken = FormatAsJson[access_token],
 AccessTokenHeader = "bearer " & AccessToken,

// Usamos ahora la busqueda con las autorizaciones que obtuvimos en los pasos previos
// en q= llamamos la palabra clave, en count=100 es el maximo de resultados permitidos para la consulta, vean la documentacion, 
// lang aca definimos la busqueda solo para idioma español, pueden poner las especificaciones que gusten segun la documentacion de la API.
 GetJsonQuery = Web.Contents("https://api.twitter.com/1.1/search/tweets.json?q=Powerbi&count=100""&lang=es",
     [
         Headers = [#"Authorization"=AccessTokenHeader]
     ]
 ),
 FormatAsJsonQuery = Json.Document(GetJsonQuery),

//luego sigue todo el trabajo de abrir el Json y  separar las columnas de acuerdo a lo que necesitamos
NavigateToStatuses = FormatAsJsonQuery[statuses],
 TableFromList = Table.FromList(NavigateToStatuses, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
 ExpandColumn = Table.ExpandRecordColumn(TableFromList, "Column1", {"created_at", "id", "id_str", "text", "truncated", "entities", "metadata", "source", "in_reply_to_status_id", "in_reply_to_status_id_str", "in_reply_to_user_id", "in_reply_to_user_id_str", "in_reply_to_screen_name", "user", "geo", "coordinates", "place", "contributors", "is_quote_status", "retweet_count", "favorite_count", "favorited", "retweeted", "possibly_sensitive", "lang", "quoted_status_id", "quoted_status_id_str", "quoted_status"}, {"created_at", "id", "id_str", "text", "truncated", "entities", "metadata", "source", "in_reply_to_status_id", "in_reply_to_status_id_str", "in_reply_to_user_id", "in_reply_to_user_id_str", "in_reply_to_screen_name", "user", "geo", "coordinates", "place", "contributors", "is_quote_status", "retweet_count", "favorite_count", "favorited", "retweeted", "possibly_sensitive", "lang", "quoted_status_id", "quoted_status_id_str", "quoted_status"}),
    #"Se expandió Column1.metadata" = Table.ExpandRecordColumn(ExpandColumn, "metadata", {"iso_language_code", "result_type"}, {"iso_language_code", "result_type"}),
    #"Se expandió user" = Table.ExpandRecordColumn(#"Se expandió Column1.metadata", "user", {"name", "screen_name", "location"}, {"name", "screen_name", "location"}),
    #"Columnas quitadas" = Table.RemoveColumns(#"Se expandió user",{"geo", "coordinates", "place", "contributors", "is_quote_status", "favorited", "retweeted", "possibly_sensitive", "lang", "quoted_status_id", "quoted_status_id_str", "quoted_status", "in_reply_to_status_id", "in_reply_to_status_id_str", "in_reply_to_user_id", "in_reply_to_user_id_str", "in_reply_to_screen_name"}),
    #"Se expandió entities" = Table.ExpandRecordColumn(#"Columnas quitadas", "entities", {"hashtags", "symbols", "user_mentions", "urls"}, {"hashtags", "symbols", "user_mentions", "urls"}),
    #"Tipo cambiado" = Table.TransformColumnTypes(#"Se expandió entities",{{"created_at", type text}}),
    #"Personalizada agregada" = Table.AddColumn(#"Tipo cambiado", "Link", each "https://www.twitter.com/"&[name]&"/status/"&[id_str]),
    #"Columnas quitadas1" = Table.RemoveColumns(#"Personalizada agregada",{"id", "truncated", "hashtags", "symbols", "user_mentions", "urls", "iso_language_code", "result_type", "source", "name"}),
    #"Dividir columna por delimitador" = Table.SplitColumn(#"Columnas quitadas1", "created_at", Splitter.SplitTextByDelimiter(" ", QuoteStyle.Csv), {"created_at.1", "created_at.2", "created_at.3", "created_at.4", "created_at.5", "created_at.6"}),
    #"Tipo cambiado1" = Table.TransformColumnTypes(#"Dividir columna por delimitador",{{"created_at.1", type text}, {"created_at.2", type text}, {"created_at.3", Int64.Type}, {"created_at.4", type time}, {"created_at.5", Int64.Type}, {"created_at.6", Int64.Type}}),
    #"Columnas quitadas2" = Table.RemoveColumns(#"Tipo cambiado1",{"created_at.1", "created_at.5"}),
    #"Columna combinada insertada" = Table.AddColumn(#"Columnas quitadas2", "Combinada", each Text.Combine({Text.From([created_at.3], "es-CL"), "-", [created_at.2], "-", Text.From([created_at.6], "es-CL")}), type text),
    #"Columnas reordenadas" = Table.ReorderColumns(#"Columna combinada insertada",{"Combinada", "created_at.2", "created_at.3", "created_at.4", "created_at.6", "id_str", "text", "screen_name", "location", "retweet_count", "favorite_count", "Link"}),
    #"Tipo cambiado2" = Table.TransformColumnTypes(#"Columnas reordenadas",{{"Combinada", type date}}),
    #"Columnas quitadas3" = Table.RemoveColumns(#"Tipo cambiado2",{"created_at.2", "created_at.3", "created_at.6"}),
    #"Columnas con nombre cambiado" = Table.RenameColumns(#"Columnas quitadas3",{{"Combinada", "Fecha Tweet"}, {"created_at.4", "Hora Tweet"}}),
    #"Tipo cambiado3" = Table.TransformColumnTypes(#"Columnas con nombre cambiado",{{"text", type text}, {"screen_name", type text}, {"id_str", type text}, {"location", type text}, {"retweet_count", Int64.Type}, {"favorite_count", Int64.Type}, {"Link", type text}})
in
    #"Tipo cambiado3"
