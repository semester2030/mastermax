import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/property_provider.dart';
import '../models/property_model.dart';
import '../services/property_service.dart';
import 'add_property_screen.dart';

class PropertyManagementScreen extends StatelessWidget {
  const PropertyManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return ChangeNotifierProvider(
      create: (context) {
        final propertyService = Provider.of<PropertyService>(context, listen: false);
        final provider = PropertyProvider(propertyService);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.loadProperties();
        });
        return provider;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'إدارة العقارات',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.add,
                color: colorScheme.onPrimary,
              ),
              onPressed: () => _navigateToAddProperty(context),
            ),
          ],
        ),
        body: Consumer<PropertyProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              );
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.error!,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.loadProperties(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                      ),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            if (provider.properties.isEmpty) {
              return Center(
                child: Text(
                  'لا توجد عقارات',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: provider.properties.length,
              itemBuilder: (context, index) {
                final property = provider.properties[index];
                return _buildPropertyCard(context, property, provider);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPropertyCard(
    BuildContext context,
    PropertyModel property,
    PropertyProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: colorScheme.surfaceContainerHighest,
          ),
          child: property.images.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    property.images.first,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.home,
                        size: 40,
                        color: colorScheme.primary,
                      );
                    },
                  ),
                )
              : Icon(
                  Icons.home,
                  size: 40,
                  color: colorScheme.primary,
                ),
        ),
        title: Text(
          property.title,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${property.price} ريال',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              property.address,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                property.status.arabicName,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: colorScheme.onSurfaceVariant,
          ),
          onSelected: (value) => _handleMenuAction(
            context,
            value,
            property,
            provider,
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'تعديل',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'حذف',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddProperty(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPropertyScreen(),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    PropertyModel property,
    PropertyProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddPropertyScreen(property: property),
          ),
        );
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'تأكيد الحذف',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.error,
              ),
            ),
            content: Text(
              'هل أنت متأكد من حذف هذا العقار؟',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'إلغاء',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  provider.deleteProperty(property.id);
                  Navigator.pop(context);
                },
                child: Text(
                  'حذف',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        );
        break;
    }
  }
} 