

default:
    @just --list


compile:
    dart pub get
    dart compile exe lib/main.dart -o vide
