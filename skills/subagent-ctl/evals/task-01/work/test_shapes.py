import unittest

from shapes import area_rect


class AreaTest(unittest.TestCase):
    def test_area(self):
        self.assertEqual(area_rect(3, 4), 12)
