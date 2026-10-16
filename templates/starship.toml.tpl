format = """
$directory\
$nodejs\
$rust\
$golang\
$php\
$fill\
$time\
\n$character"""

[fill]
symbol = " "

[directory]
style = "fg:{{ accent }}"
format = "[$path ]($style)"
truncation_length = 100
truncate_to_repo = false

[nodejs]
symbol = ""
style = "fg:{{ accent }}"
format = '[ $symbol $version ]($style)'

[rust]
symbol = ""
style = "fg:{{ accent }}"
format = '[ $symbol $version ]($style)'

[golang]
symbol = ""
style = "fg:{{ accent }}"
format = '[ $symbol $version ]($style)'

[php]
symbol = ""
style = "fg:{{ accent }}"
format = '[ $symbol $version ]($style)'

[time]
disabled = false
time_format = "%R"
style = "fg:{{ accent }}"
format = '[ $time]($style)'

[character]
success_symbol = "[➜](fg:{{ accent }})"
error_symbol = "[➜](fg:red)"