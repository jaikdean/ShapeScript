## [1.1.1](https://github.com/nicklockwood/LRUCache/releases/tag/1.1.1) (2022-07-27)

- Fixed bug where coordinates were flipped vertically when serializing path to string

## [1.1.0](https://github.com/nicklockwood/LRUCache/releases/tag/1.1.0) (2022-07-24)

- Added `SVGPath(cgPath:)` initializer for converting `CGPath` to `SVGPath`
- Added `SVGPath.string(with:)` method for serializing an `SVGPath` object back to string form
- Added `SVGPath.points()` and `SVGPath.getPoints()` methods for extracting path data
- Fixed compiler warning on older Xcode versions
- Fixed warnings on latest Xcode

## [1.0.2](https://github.com/nicklockwood/LRUCache/releases/tag/1.0.2) (2022-04-15)

- Added `SVGArc.asBezierPath()` method for converting arc to Bezier curves without needing Core Graphics

## [1.0.1](https://github.com/nicklockwood/LRUCache/releases/tag/1.0.1) (2022-04-04)

- Fix parsing scientific numbers
- Support implicit 'lineto' commands

## [1.0.0](https://github.com/nicklockwood/LRUCache/releases/tag/1.0.0) (2022-01-08)

- First release
