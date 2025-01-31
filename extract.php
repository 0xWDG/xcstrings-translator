<?php

$json = json_decode(file_get_contents('Localizable.xcstrings'), true);

// print_r($json);

foreach ($json['strings'] as $key => $value) {
    $safeKey = str_replace("\n", "\\n", $key);
    $safeKey = str_replace("\"", "\\\"", $safeKey);
    echo "\t \"".$safeKey. "\",\n";
}