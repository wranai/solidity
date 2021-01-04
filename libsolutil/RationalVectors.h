/*
	This file is part of solidity.

	solidity is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	solidity is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with solidity.  If not, see <http://www.gnu.org/licenses/>.
*/
// SPDX-License-Identifier: GPL-3.0
#pragma once

#include <libsolutil/LP.h>

#include <libsolutil/Common.h>
#include <libsolutil/CommonData.h>
#include <libsolutil/StringUtils.h>
#include <liblangutil/Exceptions.h>

#include <range/v3/view/tail.hpp>
#include <range/v3/algorithm/all_of.hpp>

#include <optional>
#include <stack>


namespace solidity::util
{

using rational = boost::rational<bigint>;

inline std::string toString(rational const& _value, size_t _paddedLength = 2)
{
	std::string result;
	if (_value == rational(bigint(1) << 256))
		result = "2**256";
	else if (_value == rational(bigint(1) << 256) - 1)
		result = "2**256-1";
	else if (_value.denominator() == bigint(1))
		result = _value.numerator().str();
	else
		result = to_string(_value);
	if (result.length() < _paddedLength)
		result = std::string(_paddedLength - result.length(), ' ') + result;
	return result;
}

/// Creates a constraint vector "_factor * x__index"
inline std::vector<rational> factorForVariable(size_t _index, rational _factor)
{
	std::vector<rational> result(_index + 1);
	result[_index] = move(_factor);
	return result;
}

inline rational const& get(std::vector<rational> const& _data, size_t _index)
{
	static rational const zero;
	return _index < _data.size() ? _data[_index] : zero;
}

template <class T>
void resizeAndSet(std::vector<T>& _data, size_t _index, T _value)
{
	if (_data.size() <= _index)
		_data.resize(_index + 1);
	_data[_index] = std::move(_value);
}

inline std::vector<rational>& operator/=(std::vector<rational>& _data, rational const& _divisor)
{
	for (rational& x: _data)
		if (x.numerator())
			x /= _divisor;
	return _data;
}

inline std::vector<rational>& operator*=(std::vector<rational>& _data, rational const& _factor)
{
	for (rational& x: _data)
		if (x.numerator())
			x *= _factor;
	return _data;
}

inline std::vector<rational> operator*(rational const& _factor, std::vector<rational> _data)
{
	for (rational& x: _data)
		if (x.numerator())
			x *= _factor;
	return _data;
}

inline std::vector<rational> operator-(std::vector<rational> const& _x, std::vector<rational> const& _y)
{
	std::vector<rational> result;
	for (size_t i = 0; i < std::max(_x.size(), _y.size()); ++i)
		result.emplace_back(get(_x, i) - get(_y, i));
	return result;
}

inline std::vector<rational>& operator-=(std::vector<rational>& _x, std::vector<rational> const& _y)
{
	solAssert(_x.size() == _y.size(), "");
	for (size_t i = 0; i < _x.size(); ++i)
		if (_y[i].numerator())
			_x[i] -= _y[i];
	return _x;
}

inline std::vector<rational> add(std::vector<rational> const& _x, std::vector<rational> const& _y)
{
	std::vector<rational> result;
	for (size_t i = 0; i < std::max(_x.size(), _y.size()); ++i)
		result.emplace_back(get(_x, i) + get(_y, i));
	return result;
}

inline bool isConstant(std::vector<rational> const& _x)
{
	return ranges::all_of(_x | ranges::views::tail, [](rational const& _v) { return _v == 0; });
}

/// Multiply two vectors where the first element of each vector is a constant factor.
/// Only works if at most one of the vector has a nonzero element after the first.
/// If this condition is violated, returns nullopt.
inline std::optional<std::vector<rational>> vectorProduct(
	std::optional<std::vector<rational>> _x,
	std::optional<std::vector<rational>> _y
)
{
	if (!_x || !_y)
		return std::nullopt;
	if (!isConstant(*_y))
		swap(_x, _y);
	if (!isConstant(*_y))
		return std::nullopt;

	rational factor = _y->front();

	for (rational& element: *_x)
		element *= factor;
	return *_x;
}

inline std::vector<bool>& operator|=(std::vector<bool>& _x, std::vector<bool> const& _y)
{
	solAssert(_x.size() == _y.size(), "");
	for (size_t i = 0; i < _x.size(); ++i)
		if (_y[i])
			_x[i] = true;
	return _x;
}

}
