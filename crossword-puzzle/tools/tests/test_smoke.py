def test_stdlib_available():
    import sqlite3
    import xml.etree.ElementTree as ET

    assert sqlite3.sqlite_version_info >= (3, 35)
    assert ET is not None
