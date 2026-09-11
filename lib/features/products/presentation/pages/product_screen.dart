import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/products/models/product.dart';

import 'add_product_screen.dart';

class ProductScreen extends StatefulWidget {
	const ProductScreen({super.key});

	@override
	State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
	final TextEditingController _searchController = TextEditingController();
	final Set<String> _expandedCategories = {};

	@override
	void dispose() {
		_searchController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Products'),
				centerTitle: true,
				backgroundColor: Colors.blue,
				foregroundColor: Colors.white,
			),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: () => Navigator.push(
					context,
					MaterialPageRoute(builder: (_) => const AddProductScreen()),
				),
				backgroundColor: Colors.blue,
				foregroundColor: Colors.white,
				icon: const Icon(Icons.add),
				label: const Text('Add Product'),
			),
			body: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					children: [
						TextField(
							controller: _searchController,
							decoration: InputDecoration(
								hintText: 'Search code / name / HSN / categoryâ€¦',
								prefixIcon: const Icon(Icons.search),
								border: OutlineInputBorder(
									borderRadius: BorderRadius.circular(12),
								),
							),
							onChanged: (_) => setState(() {}),
						),
						const SizedBox(height: 16),
						Expanded(
							child: Consumer<ProductService>(
								builder: (context, svc, _) {
									final query = _searchController.text.trim().toLowerCase();
									final allProducts = svc.products.where((p) {
										if (query.isEmpty) return true;
										return p.productName.toLowerCase().contains(query) ||
												p.productCode.toLowerCase().contains(query) ||
												p.hsnCode.toLowerCase().contains(query) ||
												p.category.toLowerCase().contains(query);
									}).toList();

									if (allProducts.isEmpty) {
										return const Center(
											child: Text(
												'No products found.',
												style: TextStyle(fontSize: 16, color: Colors.black54),
											),
										);
									}

									// Group by category
									final Map<String, List<Product>> grouped = {};
									for (final p in allProducts) {
										final cat = p.category.isEmpty ? 'Uncategorised' : p.category;
										grouped.putIfAbsent(cat, () => []).add(p);
									}
									final categories = grouped.keys.toList()..sort();

									return ListView.builder(
										itemCount: categories.length,
										itemBuilder: (context, ci) {
											final cat = categories[ci];
											final items = grouped[cat]!;										// Auto-expand first category on first view
										if (_expandedCategories.isEmpty && ci == 0) {
											WidgetsBinding.instance.addPostFrameCallback((_) {
												if (mounted) {
													setState(() => _expandedCategories.add(cat));
												}
											});
										}											final isExpanded = _expandedCategories.contains(cat);
											final totalStock = items.fold<double>(
												0, (sum, p) => sum + p.openingStock);

											return Card(
												margin: const EdgeInsets.only(bottom: 10),
												elevation: 2,
												shape: RoundedRectangleBorder(
													borderRadius: BorderRadius.circular(10),
												),
												child: Column(
													children: [
														// Category header
														InkWell(
															borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
															onTap: () => setState(() {
																if (isExpanded) {
																	_expandedCategories.remove(cat);
																} else {
																	_expandedCategories.add(cat);
																}
															}),
															child: Padding(
																padding: const EdgeInsets.symmetric(
																	horizontal: 16, vertical: 12),
																child: Row(
																	children: [
																		CircleAvatar(
																			radius: 18,
																			backgroundColor: Colors.blue.shade100,
																			child: Text(
																				cat.isNotEmpty ? cat[0].toUpperCase() : '?',
																				style: const TextStyle(
																					fontWeight: FontWeight.bold,
																					color: Colors.blue,
																				),
																			),
																		),
																		const SizedBox(width: 12),
																		Expanded(
																			child: Column(
																				crossAxisAlignment: CrossAxisAlignment.start,
																				children: [
																					Text(
																						cat,
																						style: const TextStyle(
																							fontWeight: FontWeight.bold,
																							fontSize: 15,
																						),
																					),
																					Text(
																						'${items.length} product${items.length == 1 ? '' : 's'}',
																						style: const TextStyle(
																							fontSize: 12,
																							color: Colors.black54,
																						),
																					),
																				],
																			),
																		),
																		// Closing stock summary
																		Column(
																			crossAxisAlignment: CrossAxisAlignment.end,
																			children: [
																				const Text(
																					'Closing Stock',
																					style: TextStyle(
																						fontSize: 11,
																						color: Colors.black45,
																					),
																				),
																				Text(
																					totalStock.toStringAsFixed(
																						totalStock.truncateToDouble() == totalStock ? 0 : 2),
																					style: const TextStyle(
																						fontWeight: FontWeight.bold,
																						fontSize: 15,
																						color: Colors.indigo,
																					),
																				),
																			],
																		),
																		const SizedBox(width: 8),
																		Icon(
																			isExpanded
																				? Icons.keyboard_arrow_up
																				: Icons.keyboard_arrow_down,
																			color: Colors.blue,
																		),
																	],
																),
															),
														),
														// Products under this category
														if (isExpanded) ...[
															const Divider(height: 1),
															...items.map(
																(product) => _ProductTile(
																	product: product,
																	onEdit: () => Navigator.push(
																		context,
																		MaterialPageRoute(
																			builder: (_) => AddProductScreen(
																				initialProduct: product),
																		),
																	),
																	onDelete: () => _confirmDelete(product.id),
																),
															),
														],
													],
												),
											);
										},
									);
								},
							),
						),
					],
				),
			),
		);
	}

	void _confirmDelete(String id) {
		showDialog<void>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Delete Product'),
				content: const Text('Are you sure you want to delete this product?'),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(context),
						child: const Text('Cancel'),
					),
					FilledButton(
						onPressed: () {
							context.read<ProductService>().deleteProduct(id);
							Navigator.pop(context);
						},
						child: const Text('Delete'),
					),
				],
			),
		);
	}
}

class _ProductTile extends StatelessWidget {
	const _ProductTile({
		required this.product,
		required this.onEdit,
		required this.onDelete,
	});

	final Product product;
	final VoidCallback onEdit;
	final VoidCallback onDelete;

	@override
	Widget build(BuildContext context) {
		final stock = product.openingStock;
		final stockStr = stock.toStringAsFixed(
			stock.truncateToDouble() == stock ? 0 : 2);

		return ListTile(
			contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
			leading: CircleAvatar(
				backgroundColor: Colors.orange.shade50,
				child: const Icon(Icons.inventory_2_outlined, color: Colors.orange),
			),
			title: Text(
				product.productName,
				style: const TextStyle(fontWeight: FontWeight.w600),
			),
			subtitle: Text(
				'${product.productCode}  â€¢  HSN ${product.hsnCode.isEmpty ? 'â€”' : product.hsnCode}'
				'\nâ‚¹ ${product.salesRate.toStringAsFixed(2)}  â€¢  ${product.unit}',
				style: const TextStyle(fontSize: 12),
			),
			isThreeLine: true,
			trailing: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					// Closing stock badge
					Container(
						padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
						decoration: BoxDecoration(
							color: stock <= product.minimumStock
									? Colors.red.shade50
									: Colors.green.shade50,
							borderRadius: BorderRadius.circular(8),
							border: Border.all(
								color: stock <= product.minimumStock
										? Colors.red.shade200
										: Colors.green.shade200,
							),
						),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text(
									stockStr,
									style: TextStyle(
										fontWeight: FontWeight.bold,
										fontSize: 13,
										color: stock <= product.minimumStock
												? Colors.red.shade700
												: Colors.green.shade700,
									),
								),
								Text(
									product.unit,
									style: const TextStyle(fontSize: 10, color: Colors.black54),
								),
							],
						),
					),
					PopupMenuButton<String>(
						onSelected: (value) {
							if (value == 'edit') onEdit();
							if (value == 'delete') onDelete();
						},
						itemBuilder: (_) => const [
							PopupMenuItem(value: 'edit', child: Text('Edit')),
							PopupMenuItem(value: 'delete', child: Text('Delete')),
						],
					),
				],
			),
		);
	}
}

