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

#include <libsmtutil/CHCSmtLib2Interface.h>

#include <libsolutil/Algorithms.h>
#include <libsolutil/Keccak256.h>

#include <z3++.h>

#include <boost/algorithm/string/join.hpp>
#include <boost/algorithm/string/predicate.hpp>

#include <range/v3/view.hpp>
#include <range/v3/algorithm/for_each.hpp>

#include <array>
#include <fstream>
#include <iostream>
#include <memory>
#include <stdexcept>

using namespace std;
using namespace solidity;
using namespace solidity::util;
using namespace solidity::frontend;
using namespace solidity::smtutil;

CHCSmtLib2Interface::CHCSmtLib2Interface(
	map<h256, string> const& _queryResponses,
	ReadCallback::Callback _smtCallback,
	optional<unsigned> _queryTimeout
):
	CHCSolverInterface(_queryTimeout),
	m_smtlib2(make_unique<SMTLib2Interface>(_queryResponses, _smtCallback, m_queryTimeout)),
	m_queryResponses(move(_queryResponses)),
	m_smtCallback(_smtCallback)
{
	reset();
}

void CHCSmtLib2Interface::reset()
{
	m_accumulatedOutput.clear();
	m_variables.clear();
	m_unhandledQueries.clear();
	m_sortNames.clear();
}

void CHCSmtLib2Interface::registerRelation(Expression const& _expr)
{
	smtAssert(_expr.sort);
	smtAssert(_expr.sort->kind == Kind::Function);
	if (!m_variables.count(_expr.name))
	{
		auto fSort = dynamic_pointer_cast<FunctionSort>(_expr.sort);
		string domain = toSmtLibSort(fSort->domain);
		// Relations are predicates which have implicit codomain Bool.
		m_variables.insert(_expr.name);
		write(
			"(declare-fun |" +
			_expr.name +
			"| " +
			domain +
			" Bool)"
		);
	}
}

void CHCSmtLib2Interface::addRule(Expression const& _expr, std::string const& /*_name*/)
{
	write(
		"(assert\n(forall " + forall() + "\n" +
		m_smtlib2->toSExpr(_expr) +
		"))\n\n"
	);
}

tuple<CheckResult, Expression, CHCSolverInterface::CexGraph> CHCSmtLib2Interface::query(Expression const& _block)
{
	string accumulated{};
	swap(m_accumulatedOutput, accumulated);
	solAssert(m_smtlib2, "");
	writeHeader();
	for (auto const& decl: m_smtlib2->userSorts() | ranges::views::values)
		write(decl);
	m_accumulatedOutput += accumulated;

	string queryRule = "(assert\n(forall " + forall() + "\n" +
		"(=> " + _block.name + " false)"
		"))";
	string response = querySolver(
		m_accumulatedOutput +
		queryRule +
		"\n(check-sat)"
	);
	swap(m_accumulatedOutput, accumulated);

	CheckResult result;
	// TODO proper parsing
	if (boost::starts_with(response, "sat"))
		return {CheckResult::UNSATISFIABLE, parseInvariants(response), {}};
	else if (boost::starts_with(response, "unsat"))
		return {CheckResult::SATISFIABLE, Expression (true), parseCounterexample(response)};
	else if (boost::starts_with(response, "unknown"))
		result = CheckResult::UNKNOWN;
	else
		result = CheckResult::ERROR;

	return {result, Expression(true), {}};
}

namespace
{

string readToken(string const& _data, size_t _pos)
{
	string r;
	while (_pos < _data.size())
	{
		char c = _data[_pos++];
		if (iswspace(unsigned(c)) || c == ',' || c == '(' || c == ')')
			break;
		r += c;
	}
	return r;
}

size_t skipWhitespaces(string const& _data, size_t _pos)
{
	while (_pos < _data.size() && iswspace(unsigned(_data[_pos])))
	{
		++_pos;
	}

	return _pos;
}

/// @param _data here is always going to be either
/// - term
/// - term(args)
pair<smtutil::Expression, size_t> parseExpression(string const& _data)
{
	size_t pos = skipWhitespaces(_data, 0);

	string fname = readToken(_data, pos);
	pos += fname.size();

	if (pos >= _data.size() || _data[pos] != '(')
	{
		if (fname == "true" || fname == "false")
			return {Expression(fname, {}, SortProvider::boolSort), pos};
		return {Expression(fname, {}, SortProvider::uintSort), pos};
	}

	smtAssert(_data[pos] == '(');

	vector<Expression> exprArgs;
	do
	{
		++pos;
		auto [arg, size] = parseExpression(_data.substr(pos));
		pos += size;
		exprArgs.emplace_back(move(arg));
		smtAssert(_data[pos] == ',' || _data[pos] == ')');
	} while (_data[pos] == ',');

	smtAssert(_data[pos] == ')');
	++pos;

	if (fname == "const")
		fname = "const_array";

	return {Expression(fname, move(exprArgs), SortProvider::uintSort), pos};
}

/// @param _data here is always going to be either
/// - term
/// - (term arg1 arg2 ... argk), where each arg is an sexpr.
pair<smtutil::Expression, size_t> parseSExpression(string const& _data)
{
	size_t pos = skipWhitespaces(_data, 0);

	vector<Expression> exprArgs;
	string fname;
	if (_data[pos] != '(')
	{
		fname = readToken(_data, pos);
		pos += fname.size();
	}
	else
	{
		++pos;
		fname = readToken(_data, pos);
		pos += fname.size();
		do
		{
			auto [symbArg, newPos] = parseSExpression(_data.substr(pos));
			exprArgs.emplace_back(move(symbArg));
			pos += newPos;
		} while (_data[pos] != ')');
		++pos;
	}

	if (fname == "")
		fname = "var-decl";
	else if (fname == "const")
		fname = "const_array";

	if (fname == "true" || fname == "false")
		return {Expression(fname, {}, SortProvider::boolSort), pos};

	return {Expression(fname, move(exprArgs), SortProvider::uintSort), pos};
}

smtutil::Expression parseDefineFun(string const& _data)
{
	auto [defineFun, pos] = parseSExpression(_data);

	vector<Expression> newArgs;
	Expression const& curArgs = defineFun.arguments.at(1);
	smtAssert(curArgs.name == "var-decl");
	for (auto&& curArg: curArgs.arguments)
		newArgs.emplace_back(move(curArg));

	Expression predExpr{defineFun.arguments.at(0).name, move(newArgs), SortProvider::boolSort};

	Expression& invExpr = defineFun.arguments.at(3);

	solidity::util::BreadthFirstSearch<Expression*> bfs{{&invExpr}};
	bfs.run([&](auto&& _expr, auto&& _addChild) {
		if (_expr->name == "=")
		{
			smtAssert(_expr->arguments.size() == 2);
			auto check = [](string const& _name) {
				return boost::starts_with(_name, "mapping") && boost::ends_with(_name, "length");
			};
			if (check(_expr->arguments.at(0).name) || check(_expr->arguments.at(1).name))
				*_expr = Expression(true);
		}
		for (auto& arg: _expr->arguments)
			_addChild(&arg);
	});

	Expression eq{"=", {move(predExpr), move(defineFun.arguments.at(3))}, SortProvider::boolSort};

	return eq;
}

}

CHCSolverInterface::CexGraph CHCSmtLib2Interface::parseCounterexample(string const& _result)
{
	CHCSolverInterface::CexGraph cexGraph;

	string accumulated{};
	swap(m_accumulatedOutput, accumulated);
	solAssert(m_smtlib2, "");
	for (auto const& decl: m_smtlib2->userSorts() | ranges::views::values)
		write(decl);

	for (auto&& line: _result | ranges::views::split('\n') | ranges::to<vector<string>>())
	{
		string firstDelimiter = ": ";
		string secondDelimiter = " -> ";

		size_t f = line.find(firstDelimiter);
		if (f != string::npos)
		{
			string id = line.substr(0, f);
			string rest = line.substr(f + firstDelimiter.size());

			size_t s = rest.find(secondDelimiter);
			string pred;
			string adj;
			if (s == string::npos)
				pred = rest;
			else
			{
				pred = rest.substr(0, s);
				adj = rest.substr(s + secondDelimiter.size());
			}

			if (pred == "FALSE")
				pred = "false";

			unsigned iid = unsigned(stoi(id));

			vector<unsigned> children;
			for (auto&& v: adj | ranges::views::split(',') | ranges::to<vector<string>>())
				children.emplace_back(unsigned(stoi(v)));

			auto [expr, size] = parseExpression(pred);

			cexGraph.nodes.emplace(iid, move(expr));
			cexGraph.edges.emplace(iid, move(children));
		}
	}

	return cexGraph;
}

Expression CHCSmtLib2Interface::parseInvariants(string const& _result)
{
	/*
	string z3Input;
	for (auto const& decl: m_smtlib2->userSorts() | ranges::views::values)
		z3Input += decl + '\n';
	*/

	vector<Expression> eqs;
	for (auto&& line: _result | ranges::views::split('\n') | ranges::to<vector<string>>())
	{
		if (!boost::starts_with(line, "(define-fun"))
			continue;

		eqs.emplace_back(parseDefineFun(line));
		//z3Input += line + '\n';
	}

	//z3Input += "(assert true)";

	//cout << "; z3 input:" << endl;
	//cout << z3Input << endl;

	/*
	z3::context ctx;

	auto expr = ctx.parse_string(z3Input.c_str());

	cout << "; parsed z3 expr is:" << endl;
	cout << expr << endl;
	*/

	Expression conj{"and", move(eqs), SortProvider::boolSort};
	return conj;
	//return Expression(true);
}

void CHCSmtLib2Interface::declareVariable(string const& _name, SortPointer const& _sort)
{
	smtAssert(_sort);
	if (_sort->kind == Kind::Function)
		declareFunction(_name, _sort);
	else if (!m_variables.count(_name))
	{
		m_variables.insert(_name);
		write("(declare-var |" + _name + "| " + toSmtLibSort(*_sort) + ')');
	}
}

string CHCSmtLib2Interface::toSmtLibSort(Sort const& _sort)
{
	if (!m_sortNames.count(&_sort))
		m_sortNames[&_sort] = m_smtlib2->toSmtLibSort(_sort);
	return m_sortNames.at(&_sort);
}

string CHCSmtLib2Interface::toSmtLibSort(vector<SortPointer> const& _sorts)
{
	string ssort("(");
	for (auto const& sort: _sorts)
		ssort += toSmtLibSort(*sort) + " ";
	ssort += ")";
	return ssort;
}

void CHCSmtLib2Interface::writeHeader()
{
	if (m_queryTimeout)
		write("(set-option :timeout " + to_string(*m_queryTimeout) + ")");
	write("(set-logic HORN)\n");
}

string CHCSmtLib2Interface::forall()
{
	string vars("(");
	for (auto const& [name, sort]: m_smtlib2->variables())
	{
		solAssert(sort, "");
		if (sort->kind != Kind::Function)
			vars += " (" + name + " " + toSmtLibSort(*sort) + ")";
	}
	vars += ")";
	return vars;
}

void CHCSmtLib2Interface::declareFunction(string const& _name, SortPointer const& _sort)
{
	smtAssert(_sort);
	smtAssert(_sort->kind == Kind::Function);
	// TODO Use domain and codomain as key as well
	if (!m_variables.count(_name))
	{
		auto fSort = dynamic_pointer_cast<FunctionSort>(_sort);
		smtAssert(fSort->codomain);
		string domain = toSmtLibSort(fSort->domain);
		string codomain = toSmtLibSort(*fSort->codomain);
		m_variables.insert(_name);
		write(
			"(declare-fun |" +
			_name +
			"| " +
			domain +
			" " +
			codomain +
			")"
		);
	}
}

void CHCSmtLib2Interface::write(string _data)
{
	m_accumulatedOutput += move(_data) + "\n";
}

string CHCSmtLib2Interface::querySolver(string const& _input)
{
	/*
	return "sat\n\
(define-fun block_5_function_f__12_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G Int) (H state_type) (I Int)) Bool true)\n\
(define-fun block_6_f_11_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G Int) (H state_type) (I Int)) Bool (or (not (= C abi_type)) (and (and (= I G) (= H F)) (= A 0))))\n\
(define-fun block_7_return_function_f__12_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G Int) (H state_type) (I Int)) Bool (and (and (and (>= I 0) (<= I 115792089237316195423570985008687907853269984665640564039457584007913129639935)) (or (and (exists ((var0 Bool)) (not var0)) (>= I 10)) (<= I 9))) (or (not (= C abi_type)) (and (and (= I G) (= H F)) (= A 0)))))\n\
(define-fun block_8_function_f__12_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G Int) (H state_type) (I Int)) Bool (and (and (exists ((var0 Bool)) (and (and (and (>= I 0) (<= I 115792089237316195423570985008687907853269984665640564039457584007913129639935)) (and (not var0) (>= I 10))) (not var0))) (or (not (= C abi_type)) (and (= I G) (= H F)))) (= 1 A)))\n\
(define-fun block_9_function_f__12_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G Int) (H state_type) (I Int)) Bool true)\n\
(define-fun contract_initializer_10_C_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G state_type) (H Int) (I Int)) Bool (or (not (= C abi_type)) (and (and (= I H) (= G F)) (= A 0))))\n\
(define-fun contract_initializer_after_init_12_C_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G state_type) (H Int) (I Int)) Bool (or (not (= C abi_type)) (and (and (= I H) (= G F)) (= A 0))))\n\
(define-fun contract_initializer_entry_11_C_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G state_type) (H Int) (I Int)) Bool (or (not (= C abi_type)) (and (and (= I H) (= G F)) (= A 0))))\n\
(define-fun error_target_3_0 () Bool false)\n\
(define-fun implicit_constructor_entry_13_C_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G state_type) (H Int) (I Int)) Bool (and (>= (select (balances G) B) (msg.value E)) (and (and (and (= 0 A) (= G F)) (= 0 H)) (= 0 I))))\n\
(define-fun interface_0_C_13_0 ((A Int) (B abi_type) (C crypto_type) (D state_type) (E Int)) Bool (= E 0))\n\
(define-fun nondet_interface_1_C_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E state_type) (F Int) (G state_type) (H Int)) Bool true)\n\
(define-fun summary_3_function_f__12_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G Int) (H state_type) (I Int)) Bool (and (and (= H F) (= I G)) (or (and (= A 1) (and (<= G 115792089237316195423570985008687907853269984665640564039457584007913129639935) (>= G 10))) (= A 0))))\n\
(define-fun summary_4_function_f__12_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G Int) (H state_type) (I Int)) Bool (and (and (exists ((var0 Int)) (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (and (= (select (bytes_tuple_accessor_array (msg.data E)) 3) 240) (= (select (bytes_tuple_accessor_array (msg.data E)) 2) 31)) (= (select (bytes_tuple_accessor_array (msg.data E)) 1) 18)) (= (select (bytes_tuple_accessor_array (msg.data E)) 0) 38)) (= (msg.sig E) 638722032)) (= (msg.value E) 0)) (= (state_type (store (balances F) B (+ (select (balances F) B) var0))) H)) (>= (bytes_tuple_accessor_length (msg.data E)) 4)) (<= (tx.gasprice E) 115792089237316195423570985008687907853269984665640564039457584007913129639935)) (>= (tx.gasprice E) 0)) (<= (tx.origin E) 1461501637330902918203684832716283019655932542975)) (>= (tx.origin E) 0)) (<= (msg.sender E) 1461501637330902918203684832716283019655932542975)) (>= (msg.sender E) 0)) (<= (block.timestamp E) 115792089237316195423570985008687907853269984665640564039457584007913129639935)) (>= (block.timestamp E) 0)) (<= (block.number E) 115792089237316195423570985008687907853269984665640564039457584007913129639935)) (>= (block.number E) 0)) (<= (block.gaslimit E) 115792089237316195423570985008687907853269984665640564039457584007913129639935)) (>= (block.gaslimit E) 0)) (<= (block.difficulty E) 115792089237316195423570985008687907853269984665640564039457584007913129639935)) (>= (block.difficulty E) 0)) (<= (block.coinbase E) 1461501637330902918203684832716283019655932542975)) (>= (block.coinbase E) 0)) (<= (block.chainid E) 115792089237316195423570985008687907853269984665640564039457584007913129639935)) (>= (block.chainid E) 0)) (<= (block.basefee E) 115792089237316195423570985008687907853269984665640564039457584007913129639935)) (>= (block.basefee E) 0)) (>= var0 0)) (>= (- (* (- 1) (select (balances F) B)) var0) (- 115792089237316195423570985008687907853269984665640564039457584007913129639935))) (>= (+ (select (balances F) B) var0) 0))) (or (and (= A 1) (and (<= G 115792089237316195423570985008687907853269984665640564039457584007913129639935) (>= G 10))) (= A 0))) (= G I)))\n\
(define-fun summary_constructor_2_C_13_0 ((A Int) (B Int) (C abi_type) (D crypto_type) (E tx_type) (F state_type) (G state_type) (H Int) (I Int)) Bool (and (= G F) (and (and (and (= A 0) (= H 0)) (= I 0)) (and (>= (select (balances F) B) (msg.value E)) (= (balances F) (balances F))))))\n";
	*/
	util::h256 inputHash = util::keccak256(_input);
	if (m_queryResponses.count(inputHash))
		return m_queryResponses.at(inputHash);
	if (m_smtCallback)
	{
		auto result = m_smtCallback(ReadCallback::kindString(ReadCallback::Kind::SMTQuery), _input);
		if (result.success)
			return result.responseOrErrorMessage;
	}
	m_unhandledQueries.push_back(_input);
	return "unknown\n";
}
