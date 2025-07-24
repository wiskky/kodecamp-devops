from app import add, subtract

def test_add():
    assert add(2, 5) == 7
    assert add(-1, 4) == 3

def test_subtract():
    assert subtract(10, 4) == 6
    assert subtract(0, 3) == -3

